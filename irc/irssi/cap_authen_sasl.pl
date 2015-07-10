use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

use MIME::Base64;
use Authen::SASL "Perl";

$VERSION = "1.1";

%IRSSI = (
    authors     => ['Mantas Mikulėnas',
					'Michael Tharp',
					'Jilles Tjoelker'],
    contact     => ['grawity@gmail.com',
					'gxti@partiallystapled.com'],
    name        => 'cap_authen_sasl.pl',
    description => 'Implements SASL authentication using Authen::SASL for use with charybdis ircds, and enables CAP MULTI-PREFIX',
    license     => 'GNU General Public License',
    url         => 'http://sasl.charybdis.be/',
);

my %sasl_auth = ();

sub timeout;

sub server_connected {
	my ($server) = @_;
	if ($server->{chat_type} eq "IRC") {
			$server->send_raw_now("CAP LS");
	}
}

sub event_cap {
	my ($server, $args, $nick, $address) = @_;
	my ($subcmd, $caps, $tosend);

	$tosend = '';
	if ($args =~ /^\S+ (\S+) :(.*)$/) {
		$subcmd = uc $1;
		$caps = ' '.$2.' ';
		if ($subcmd eq 'LS') {
			$tosend .= ' multi-prefix' if $caps =~ / multi-prefix /i;
			$tosend .= ' sasl' if $caps =~ / sasl /i && defined($sasl_auth{$server->{tag}});
			$tosend =~ s/^ //;
			$server->print('', "CLICAP: supported by server:$caps");
			if (!$server->{connected}) {
				if ($tosend eq '') {
					$server->send_raw_now("CAP END");
				} else {
					$server->print('', "CLICAP: requesting: $tosend");
					$server->send_raw_now("CAP REQ :$tosend");
				}
			}
			#Irssi::signal_stop();
		} elsif ($subcmd eq 'ACK') {
			$server->print('', "CLICAP: now enabled:$caps");
			if ($caps =~ / sasl /i) {
				my $sasl = $sasl_auth{$server->{tag}};
				$sasl->{buffer} = "";
				$sasl->{obj} = Authen::SASL->new($sasl->{mech},
					callback => {
						user => $sasl->{user},
						pass => $sasl->{password}
					})->client_new("host", $server->{address});
				$sasl->{started} = 0;
				if($sasl->{obj}) {
					$server->send_raw_now("AUTHENTICATE " . $sasl->{mech});
					Irssi::timeout_add_once(10*1000, \&timeout, $server->{tag});
				}else{
					$server->print('', 'SASL: attempted to start unknown mechanism "' . $sasl->{mech} . '"');
				}
			}
			elsif (!$server->{connected}) {
				$server->send_raw_now("CAP END");
			}
			#Irssi::signal_stop();
		} elsif ($subcmd eq 'NAK') {
			$server->print('', "CLICAP: refused:$caps");
			if (!$server->{connected}) {
				$server->send_raw_now("CAP END");
			}
			#Irssi::signal_stop();
		} elsif ($subcmd eq 'LIST') {
			$server->print('', "CLICAP: currently enabled:$caps");
			#Irssi::signal_stop();
		}
	}
}

sub event_authenticate {
	my ($server, $args, $nick, $address) = @_;
	my $sasl = $sasl_auth{$server->{tag}};
	return unless $sasl && $sasl->{obj};

	$sasl->{buffer} .= $args;
	return if length($args) == 400;
	my $in = $sasl->{buffer} eq '+' ? '' : decode_base64($sasl->{buffer});

	my $out;

	if (!$sasl->{started}) {
		if ($in) {
			$out = $sasl->{obj}->client_start();
			if ($out) {
				$server->print("", "SASL: Sanity check: both server and client want to go first", "CLIENTERROR");
				return sasl_abort($server);
			}
			$out = $sasl->{obj}->client_step($in);
		} else {
			$out = $sasl->{obj}->client_start();
		}
		$sasl->{started} = 1;
	} else {
		$out = $sasl->{obj}->client_step($in);
	}

	$out = ($out // '') eq '' ? '+' : encode_base64($out, '');

	while(length $out >= 400) {
		my $subout = substr($out, 0, 400, '');
		$server->send_raw_now("AUTHENTICATE $subout");
	}
	if(length $out) {
		$server->send_raw_now("AUTHENTICATE $out");
	}else{ # Last piece was exactly 400 bytes, we have to send some padding to indicate we're done
		$server->send_raw_now("AUTHENTICATE +");
	}

	$sasl->{buffer} = '';
	Irssi::signal_stop();
}

sub event_saslend {
	my ($server, $args, $nick, $address) = @_;

	my $data = $args;
	$data =~ s/^\S+ :?//;
	# need this to see it, ?? -- jilles
	$server->print('', $data);
	if (!$server->{connected}) {
		$server->send_raw_now("CAP END");
	}
}

sub event_sasl_authed {
	my ($server, $args, $nick, $address) = @_;

	my ($mynick, $mynuh, $authcid, $text) = split / /, $args, 4;
	$server->print("", "Authenticated as $authcid ($mynuh)");
	# CAP END will be sent by 903
}

sub timeout {
	my ($tag) = @_;
	my $server = Irssi::server_find_tag($tag);
	if($server and !$server->{connected}) {
		$server->print('', "SASL: authentication timed out");
		$server->send_raw_now("CAP END");
	}
}

sub sasl_abort {
	my ($server) = @_;
	$server->send_raw_now("AUTHENTICATE *");
	$server->send_raw_now("CAP END");
}

sub has_mech {
	return defined eval {Authen::SASL->new(shift)->client_new};
}

sub cmd_sasl {
	my ($data, $server, $item) = @_;

	if ($data ne '') {
		Irssi::command_runsub ('sasl', $data, $server, $item);
	} else {
		cmd_sasl_show(@_);
	}
}

sub cmd_sasl_set {
	my ($data, $server, $item) = @_;

	if (my($net, $u, $p, $m) = $data =~ /^(\S+) (\S+) (\S+) (\S+)$/) {
		$m = uc $m;
		if(has_mech $m) {
			$sasl_auth{$net}{user} = $u;
			$sasl_auth{$net}{password} = $p;
			$sasl_auth{$net}{mech} =$m;
			Irssi::print("SASL: added $net: [$m] $sasl_auth{$net}{user} *");
		}else{
			Irssi::print("SASL: unknown mechanism $m");
		}
	} elsif ($data =~ /^(\S+)$/) {
		$net = $1;
		if (defined($sasl_auth{$net})) {
			delete $sasl_auth{$net};
			Irssi::print("SASL: deleted $net");
		} else {
			Irssi::print("SASL: no entry for $net");
		}
	} else {
		Irssi::print("SASL: usage: /sasl set <net> <user> <password or keyfile> <mechanism>");
	}
}

sub cmd_sasl_show {
	#my ($data, $server, $item) = @_;
	my $count = 0;

	for my $net (keys %sasl_auth) {
		Irssi::print("SASL: $net: [$sasl_auth{$net}{mech}] $sasl_auth{$net}{user} *");
		$count++;
	}
	Irssi::print("SASL: no networks defined") if !$count;
}

sub cmd_sasl_save {
	#my ($data, $server, $item) = @_;
	my $file = Irssi::get_irssi_dir()."/sasl.auth";
	open my $fh, ">", $file or return;
	for my $net (keys %sasl_auth) {
		printf $fh ("%s\t%s\t%s\t%s\n", $net, $sasl_auth{$net}{user}, $sasl_auth{$net}{password}, $sasl_auth{$net}{mech});
	}
	close $fh;
	Irssi::print("SASL: auth saved to $file");
}

sub cmd_sasl_load {
	#my ($data, $server, $item) = @_;
	my $file = Irssi::get_irssi_dir()."/sasl.auth";

	open my $fh, "<", $file or return;
	%sasl_auth = ();
	while (<$fh>) {
		chomp;
		my ($net, $u, $p, $m) = split (/\t/, $_, 4);
		$m ||= "PLAIN";
		if(has_mech(uc $m)) {
			$sasl_auth{$net}{user} = $u;
			$sasl_auth{$net}{password} = $p;
			$sasl_auth{$net}{mech} = uc $m;
		}else{
			Irssi::print("SASL: unknown mechanism $m");
		}
	}
	close $fh;
	Irssi::print("SASL: auth loaded from $file");
}

#sub cmd_sasl_mechanisms {
#	Irssi::print("SASL: mechanisms supported: " . join(" ", keys %mech));
#}

Irssi::signal_add_first('server connected', \&server_connected);
Irssi::signal_add('event cap', \&event_cap);
Irssi::signal_add('event authenticate', \&event_authenticate);
# 900 nick nick!user@host authcid :Logged in
# 903 nick :SASL auth successful
Irssi::signal_add('event 900', \&event_sasl_authed);
Irssi::signal_add('event 903', \&event_saslend);
Irssi::signal_add('event 904', \&event_saslend);
Irssi::signal_add('event 905', \&event_saslend);
Irssi::signal_add('event 906', \&event_saslend);
Irssi::signal_add('event 907', \&event_saslend);

Irssi::command_bind('sasl', \&cmd_sasl);
Irssi::command_bind('sasl load', \&cmd_sasl_load);
Irssi::command_bind('sasl save', \&cmd_sasl_save);
Irssi::command_bind('sasl set', \&cmd_sasl_set);
Irssi::command_bind('sasl show', \&cmd_sasl_show);
#rssi::command_bind('sasl mechanisms', \&cmd_sasl_mechanisms);

cmd_sasl_load();

# vim: ts=4
