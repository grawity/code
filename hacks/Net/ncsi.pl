#!/usr/bin/env perl
use v5.14;
use warnings;
use strict;
use LWP::Simple;
use Net::DBus;
use Net::DBus::Reactor;

# configuration
#
# ordered from fastest to slowest

my $test_url = "http://www.msftncsi.com/ncsi.txt";
my $test_body = "Microsoft NCSI";

#my $test_url = "http://detectportal.firefox.com/success.txt";
#my $test_body = "success";

#my $test_url = "http://fedoraproject.org/static/hotspot.txt";
#my $test_body = "OK";

#my $test_url = "http://nmcheck.gnome.org/check_network_status.txt";
#my $test_body = "NetworkManager is online";

my $interval = 5 * 60;

# copypasta

sub _debug { warn "debug: @_\n" if $ENV{DEBUG}; }
sub _warn  { warn "warning: @_\n"; }
sub _err   { warn "error: @_\n"; }
sub _die   { _err(@_); exit 1; }

sub Notifications {
	Net::DBus->session
	->get_service("org.freedesktop.Notifications")
	->get_object("/org/freedesktop/Notifications")
}

sub notify {
	state $id = 0;
	my ($summary, %opts) = @_;

	if ($summary) {
		$id = Notifications->Notify(
			$opts{app} // "ncsi",
			$id,
			$opts{icon} // undef,
			$summary,
			$opts{body},
			$opts{actions} // [],
			$opts{hints} // {},
			$opts{timeout} // 1_000);
	} else {
		Notifications->CloseNotification($id);
	}
}

# main code

sub is_online {
	_debug("fetching <$test_url>");
	my $body = get($test_url);
	return 0 if !defined($body);
	chomp($body);
	return ($body eq $test_body);
}

my $reactor = Net::DBus::Reactor->main();
my $was_online = 1;

_debug("polling every $interval seconds");
$reactor->add_timeout($interval * 1_000, sub {
	my $is_online = is_online();
	_debug("was online [$was_online] -> is online [$is_online]");
	if ($was_online && !$is_online) {
		notify("No Internet access",
			body => "Connectivity check failed");
	}
	$was_online = $is_online;
});
_debug("running main loop");
$reactor->run();
