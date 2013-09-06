#!/usr/bin/env perl
use utf8;
use warnings;
use strict;
use constant {ACCEPT => 1, REJECT => 0};
use IO::Poll qw(POLLIN POLLHUP);
use IO::Socket::INET;
use IO::Socket::SSL;
use Socket qw(SHUT_RDWR);

my $listenport;
my $connecthost;
my $connectssl;
my $connectport;
my @listeners;
my $verbose;

my %ui = (
	client_t => "\e[1;35mclient\e[m",
	server_t => "\e[1;36mserver\e[m",
	blocked_t => "\e[1;31mblocked\e[m",
	client_c => "\e[35m",
	server_c => "\e[36m",
	blocked_c => "\e[31m",
);

sub filter_outgoing {
	my $data = shift;
	return ACCEPT;
}

sub filter_incoming {
	my $data = shift;
	for ($data) {
		return REJECT if /سمَـَّوُوُحخ/ or /مارتيخ/;
		return REJECT if /this is an example regex/;
	}
	return ACCEPT;
}

sub trace {
	print $0, "[$$]: ", @_, "\n";
}

sub forked(&) {
	my $code = shift;
	my $pid = fork();
	if ($pid) { return $pid; }
	else { exit &$code; }
}

sub escape {
	my $str = shift;
	my $len = length($str);
	$str =~ s/([^\x20-\x7F])/sprintf "\\x%02X", ord($1)/ge;
	return "[".$len."] ".$str;
}

sub create_listeners {
	push @listeners, IO::Socket::INET->new(
					LocalAddr => "127.0.0.1",
					LocalPort => $listenport,
					Proto => "tcp",
					Listen => 5,
					ReuseAddr => 1,
				) or warn "bind failed: $@\n";

	if (eval {require IO::Socket::INET6}) {
		push @listeners, IO::Socket::INET6->new(
					LocalAddr => "::1",
					LocalPort => $listenport,
					Proto => "tcp",
					Listen => 5,
					ReuseAddr => 1,
				) or warn "bind failed: $@\n";
	}
}

sub accept_loop {
	$SIG{CHLD} = "IGNORE";

	my $poll = IO::Poll->new;
	$poll->mask($_, POLLIN) for @listeners;

	trace("listening for connections");
	while ($poll->poll > -1) {
		for my $fh ($poll->handles(POLLIN)) {
			forked { accept_conn($fh->accept) };
		}
	}
}

sub accept_conn {
	my ($client_conn) = @_;

	trace("accepted connection $client_conn");

	my $server_conn;

	if ($connectssl) {
		$server_conn = IO::Socket::SSL->new(
					PeerAddr => $connecthost,
					PeerPort => $connectport,
					Proto => "tcp",
					MultiHomed => 1,
					SSL_verify_mode => SSL_VERIFY_PEER,
					SSL_ca_path => "/etc/ssl/certs",
				) or die "connect failed: $@\n";
	} else {
		$server_conn = IO::Socket::INET->new(
					PeerAddr => $connecthost,
					PeerPort => $connectport,
					Proto => "tcp",
					MultiHomed => 1,
				) or die "connect failed: $@\n";
	}

	my $poll = IO::Poll->new;
	my %buf;

	for my $fh ($client_conn, $server_conn) {
		$fh->autoflush(1);
		$poll->mask($fh, POLLIN|POLLHUP);
		$buf{$fh} = "";
	}

	while ($poll->poll > -1) {
		for my $fh ($poll->handles(POLLHUP)) {
			if ($fh == $client_conn) {
				trace($ui{client_t}." -- closed connection, exiting");
			}
			elsif ($fh == $server_conn) {
				trace($ui{server_t}." -- closed connection, exiting");
			}
			else {
				trace("got POLLHUP from unknown filehandle $fh, removing");
				$poll->mask($fh, 0);
			}
			exit;
		}
		for my $fh ($poll->handles(POLLIN)) {
			my $nread = $fh->sysread($buf{$fh}, 4096, length($buf{$fh}));
			if (!$nread) {
				trace("read nothing from $fh, closing");
				$fh->shutdown(SHUT_RDWR);
				next;
			}
			trace("buffer -- ".escape($buf{$fh})) if $verbose;
			while ($buf{$fh} =~ s/^(.*\n)//) {
				my $data = $1;
				if (!length $data) {
					trace("eof");
					next;
				}
				if ($fh == $client_conn) {
					if (filter_outgoing($data)) {
						trace($ui{client_t}." -> ".$ui{client_c}.escape($data)."\e[m")
							if $verbose;
						$server_conn->print($data);
					} else {
						trace($ui{blocked_t}." -> ".$ui{client_c}.escape($data)."\e[m");
						$client_conn->print("NOTICE * :Blocked line from yourself.\r\n");
					}
				}
				elsif ($fh == $server_conn) {
					if (filter_incoming($data)) {
						trace($ui{server_t}." <- ".$ui{server_c}.escape($data)."\e[m")
							if $verbose;
						$client_conn->print($data);
					} else {
						trace($ui{blocked_t}." -> ".$ui{server_c}.escape($data)."\e[m");
						if ($data =~ /^:(\S+)/) {
							$client_conn->print("NOTICE * :Blocked line from \"$1\".\r\n");
						} else {
							$client_conn->print("NOTICE * :Blocked line from server.\r\n");
						}
					}
				}
				else {
					trace("got POLLIN from unknown filehandle $fh, removing");
					$poll->mask($fh, 0);
				}
			}
			if (length $buf{$fh}) {
				trace("leftover -- ".escape($buf{$fh})) if $verbose;
			}
		}
	}
}

for (@ARGV) {
	if (/^(\d+)$/) {
		$listenport = $1;
	}
	elsif (/^(.+):(\+?)(\d+)$/) {
		$connecthost = $1;
		$connectssl = ($2 eq "+");
		$connectport = $3;
	}
	elsif ($_ eq "-v") {
		$verbose = 1;
	}
}

if ($listenport && length($connecthost) && $connectport) {
	create_listeners();
	exit if !@listeners;
	accept_loop();
}
