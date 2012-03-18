#!/usr/bin/env perl
# vim: ts=3:sw=3:et
use common::sense;
use Data::Dumper;
use User::pwent;

package Logger;

sub new {
   my $class = shift;
   my $self = {};
   $self->{hooks} = [];
   $self->{pending} = {};
   bless $self, $class;
}

sub addhook($&) {
   my ($self, $hook) = @_;
   push @{$self->{hooks}}, $hook;
}

sub event {
   my ($self, %data) = @_;
   $self->update(%data);
   warn "calling hooks\n";
   for my $hook (@{$self->{hooks}}) {
      $hook->($self->{pending});
   }
   $self->reset;
}

sub update {
   my ($self, %data) = @_;
   for my $k (keys %data) {
      warn "update: $k = $data{$k}\n";
      $self->{pending}{$k} = $data{$k};
   }
}

sub reset {
   my ($self) = @_;
   $self->{pending} = {};
}

package main;

my $logger = Logger->new;

sub get_user_by_uid {
   getpwuid(shift);
}

sub parse_text {
   state %systemd_sessions;
   state %event;

   my ($app, $text) = @_;
   $event{SERVICE} = $app;
   $event{RAW_LOG} = $text;
   $event{PRIORITY} = "notice";

   given ($app) {
      when ("chrony") {
         given ($text) {
            when ("Can't synchronize: no majority") {
               $event{PRIORITY}  = "error";
               $event{message}   = "cannot synchronize: no majority";
            }
         }
      }
      when (m!/sbin/crond?$|^crontab$!i) {
         $event{SERVICE} = "cron";
         if ($text =~ /^\((.+?)\) (.+?) \((.+)\)(?:: (.+?))?$/) {
            given ($2) {
               when ("CAN'T OPEN") {
                  $event{PRIORITY}  = "warning";
                  $event{message}   = "unable to open crontab: $4";
                  $event{object}    = $3;
               }
               when ("CMD") {
                  $event{PRIORITY}  = "info";
                  $event{TYPE}      = "job start";
                  $event{message}   = "scheduled job started";
                  $event{user}      = $1;
                  $event{command}   = $3;
               }
               when ("BEGIN EDIT") {
                  next;
               }
               when ("END EDIT") {
                  next;
               }
               when ("INFO") {
                  $event{PRIORITY}  = "notice";
                  $event{message}   = $3;
               }
               when ("LIST") {
                  $event{PRIORITY}     = "info";
                  $event{TYPE}         = "privileged read";
                  $event{user}         = $1;
                  $event{object}       = "crontab: user/$3";
                  $event{targetuser}   = $3;
               }
               when ("ORPHAN") {
                  $event{PRIORITY}     = "warning";
                  $event{message}      = "crontab owner not found";
                  $event{object}       = $1;
                  $event{details}      = $3;
               }
               when ("RELOAD") {
                  next;
               }
               when ("REPLACE") {
                  $event{PRIORITY}     = "notice";
                  $event{TYPE}         = "privileged write";
                  $event{user}         = $1;
                  $event{object}       = "crontab: user/$3";
                  $event{targetuser}   = $3;
               }
            }
         }
      }
      when ("dhclient") {
         given ($text) {
            when (/^DHCPREQUEST on (\S+) to (\S+) port \d+$/) {
               $event{PRIORITY}     = "info";
               $event{TYPE}         = "network connection";
               $event{message}      = "requesting DHCP lease";
               $event{net_interface}   = $1;
               $event{dhcp_server}     = $2;
            }
            when (/^DHCPACK from (\S+)$/) {
               $event{PRIORITY}     = "info";
               $event{TYPE}         = "network connection";
               $event{message}      = "acknowledging DHCP lease";
               $event{dhcp_server}     = $1;
            }
            when (/^bound to (\S+) -- renewal in (\d+) seconds\.$/) {
               $event{PRIORITY}     = "info";
               $event{TYPE}         = "network connection";
               $event{message}      = "obtained DHCP lease";
               $event{ip_address}   = $1;
               $event{dhcp_expiry}  = $2;
            }
         }
      }
      when ("dhcpcd") {
         given ($text) {
            when (/^(\w+): renewing lease of (.+?)$/) {
               $event{PRIORITY}     = "info";
               $event{TYPE}         = "network connection";
               $event{message}      = "renewing DHCP lease";
               $event{net_interface}   = $1;
               $event{ip_address}      = $2;
            }
            when (/^(\w+): acknowledged (.+?) from (.+?)$/) {
               $event{PRIORITY}     = "info";
               $event{TYPE}         = "network connection";
               $event{message}      = "acknowledging DHCP lease";
               $event{net_interface}   = $1;
               $event{ip_address}      = $2;
               $event{dhcp_server}     = $3;
            }
            when (/^(\w+): leased (.+?) for (\d+) seconds$/) {
               $event{PRIORITY}        = "info";
               $event{TYPE}            = "network connection";
               $event{message}         = "obtained DHCP lease";
               $event{net_interface}   = $1;
               $event{ip_address}      = $2;
               $event{dhcp_expiry}     = $3;
            }
         }
      }
      when ("dovecot") {
         sub kvsplit { my $_; map {/=/ ? split(/=/, $_, 2) : ($_, 1)} split(/, /, shift) }
         given ($text) {
            when (/^(\w+)-login: Disconnected \((.+?)\): (.+)(?: from dovecot)?$/) {
               my %data = kvsplit($3);
               $event{PRIORITY}     = "info";
               $event{TYPE}         = "user logout";
               $event{protocol}     = $1;
               $event{details}      = $2;
               $event{remote_addr}  = $data{rip};
               $event{local_addr}   = $data{lip};
               given ($event{details}) {
                  when ("tried to use disabled plaintext auth") {
                     $event{PRIORITY}  = "warning";
                     $event{TYPE}      = "authorization failed";
                  }
               }
            }
            when (/^(\w+)-login: Login: (.+)$/) {
               my %data = kvsplit($2);
               $event{PRIORITY}  = "notice";
               $event{TYPE}      = "user login";
               $event{protocol}  = $1;
               ($event{user})    = $data{user} =~ /^\<(.+)\>$/;
               $event{auth_mech} = "sasl/".$data{method};
               $event{remote_addr}  = $data{rip};
               $event{local_addr}   = $data{lip};
               $event{secure}    = $data{secured}?"yes":"no";
            }
            when (/^(\w+)\((.+?)\): Disconnected: (.+) bytes=/) {
               $event{PRIORITY}  = "info";
               $event{TYPE}      = "user logout";
               $event{details}   = $3;
               $event{protocol}  = $1;
               $event{user}      = $2;
            }
         }
      }
      when ("exim") {
         given ($text) {
            when (/^Start queue run: pid=\d+ (.+?)$/) {
               $entry{class} = "mail";
               $event{desc} = "job start: mail queue";
               #$event{options} = $1;
            }
            when (/^End queue run: pid=\d+ (.+?)$/) {
               $entry{class} = "mail";
               $event{desc} = "job finish: mail queue";
               #$event{options} = $1;
            }
         }
      }
      when ("named") {
         given ($text) {
            when (/^client (\S+)#(\d+): query \(\w+\) '(\S+)' denied$/) {
               $entry{priority}     = "notice";
               $event{desc}         = "authorization failed: DNS query refused";
               $event{query}        = $3;
               $event{remote_addr}  = $1;
               $event{remote_port}  = $2;
            }
            when (/^zone (\S+)\/(\w+): loaded serial (\d+)$/) {
               $entry{priority}     = "info";
               $event{desc}         = "service reload: DNS zone updated";
               $event{dns_zone}     = $1;
               $event{dns_serial}   = $3;
            }
         }
      }
      when (/^ovpn-/) {
         given ($text) {
            when (/^(\S+?):(\d+) \[(.+?)\] Peer Connection Initiated with /) {
               $entry{priority}  = "notice";
               $event{desc}      = "user login";
               $event{user}      = $3;
               $event{protocol}  = "openvpn";
               $event{remote_addr}  = $1;
               $event{remote_port}  = $2;
            }
         }
      }
      when ("rtkit-daemon") {
         given ($text) {
            when (/^Successfully made thread (\d+) of process (\d+) \((.+?)\) owned by '(.+?)' high priority at nice level (-?\d+)\.$/) {
               $entry{priority}     = "notice";
               $event{desc}         = "privileged resource use";
               $event{user}         = getpwuid($4)->name;
               $event{object}       = "CPU priority: $5";
               $event{process}      = $3;
               $event{target_pid}   = $2;
               $event{target_tid}   = $1;
            }
         }
      }
      when ("sshd") {
         $event{protocol} = "ssh";
         given ($text) {
            when (/^Authorized to (.+?), krb5 principal (.+?) \((krb5_kuserok)\)$/) {
               $event{desc} = "user authorization";
               $event{user} = $1;
               $event{authz_mech} = $3;
               $event{krb5_principal} = $2;
            }
            when (/^Accepted (\S+) for (.+?) from (\S+) port (\d+) (\w+)$/) {
               $entry{priority}     = "notice";
               $event{desc}         = "user login";
               $event{user}         = $2;
               $event{authn_mech}   = "ssh2/$1";
               $event{remote_addr}  = $3;
               $event{remote_port}  = $4;
               $event{protocol}     = $5;
            }
            default {
               $event{desc}         = $text;
            }
         }
      }
      when ("sudo") {
         given ($text) {
            when (/^(.+?)\s*: (.+)$/) {
               my %k = map {split /=/, $_, 2} split(/ ; /, $2, 4);
               $entry{priority}     = "notice";
               $event{desc}         = "privileged command";
               $event{user}         = $1;
               $event{tty}          = $k{TTY};
               $event{pwd}          = $k{PWD};
               $event{targetuser}   = $k{USER};
               $event{command}      = $k{COMMAND};
            }
         }
      }
      when ("systemd-logind") {
         $entry{class} = "auth";
         given ($text) {
            when (/^New user (.+?) logged in\.$/) {
               $entry{priority}  = "info";
               $event{desc}      = "user login";
               $event{user}      = $1;
            }
            when (/^User (.+?) logged out\.$/) {
               $entry{priority}  = "info";
               $event{desc}      = "user logout";
               $event{user}      = $1;
            }
            when (/^New session (\d+) of user (.+?)\.$/) {
               $entry{priority}  = "info";
               $event{desc}      = "session open";
               $event{session}   = $1;
               $event{user}      = $2;
               $systemd_sessions{$event{session}} = $event{user};
            }
            when (/^Removed session (\d+)\.$/) {
               $entry{priority}  = "info";
               $event{desc}      = "session close";
               $event{session}   = $1;
               $event{user}      = $systemd_sessions{$event{session}};
               delete $systemd_sessions{$event{session}};
            }
         }
      }
      when ("xinetd") {
         given ($text) {
            when (/^libwrap refused connection to (\S+) \(libwrap=(\S+)\) from (\S+)$/) {
               $entry{priority}     = "warning";
               $event{desc}         = "authorization failed";
               $event{details}      = "refused by libwrap";
               $event{service}      = $2;
               $event{inetd_service}   = $1;
               $event{remote_addr}  = $3;
            }
         }
      }
      default {
         return undef;
      }
   }
   if (defined $entry{event}{remote_addr}) {
      $entry{event}{remote_addr} =~ s/^::ffff://;
   }
   return \%entry;
}

sub parse_dmesg {
   my ($line) = @_;
   my ($offset, $ident, $pid, $text);
   if ($line =~ /^\[\s*(\d+\.\d+)] (.+)$/) {
      $offset = $1;
      $line = $2;
   }
   if ($line =~ /^([^:]+?): (.+)$/) {
      $ident = $1;
      $text = $2;
   }
   if ($ident =~ /^(.+)\[(\d+)\]$/) {
      $ident = $1;
      $pid = $2;
   }
   return ($offset, $ident, $pid, $text);
}

sub parse_syslog {
   my ($line) = @_;
   my ($offset, $ident, $pid, $text);
   if ($line =~ /^(\w+\s+\d+\s+\d+:\d+:\d+) (\S+) (.+)$/) {
      $offset = $1;
      $line = $3;
   }
   if ($line =~ /^([^:]+?): (.+)$/) {
      $ident = $1;
      $text = $2;
   }
   if ($ident =~ /^(.+)\[(\d+)\]$/) {
      $ident = $1;
      $pid = $2;
   }
   return ($offset, $ident, $pid, $text);
}

sub output_entry {
   my ($entry) = @_;
   my $color = {
      error    => "1;31",
      warning  => "1;33",
      notice   => "1;32",
      info     => "34",
   }->{$entry->{priority}};
   printf "%14s: \e[%sm%s\e[m: \e[%sm%s\e[m\n",
               "EVENT", "", $entry->{app}, $color, $entry->{event}{desc};
   for my $k (sort keys %{$entry->{event}}) {
      next if $k eq 'desc';
      printf "%14s: %s\n", $k, $entry->{event}{$k};
   }
   printf "\n";
}

while (<STDIN>) {
   chomp(my $line = $_);
   my @l;
   if ($line =~ /^\[/) {
      @l = parse_dmesg($line);
   }
   else {
      @l = parse_syslog($line);
   }
   my ($time, $app, $pid, $text) = @l;
   my $entry = parse_text($app, $text);

   if (keys %{$entry->{event}}) {
      output_entry($entry);
   }
   else { print STDERR "$app: $text\n"; }
}
