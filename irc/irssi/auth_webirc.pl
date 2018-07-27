# vim: ft=perl
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.8";
%IRSSI = (
	name        => 'auth_webirc.pl',
	description => 'Implements WEBIRC authentication for UnrealIRCd',
	license     => 'MIT (Expat) <https://spdx.org/licenses/MIT>',
);

my %networks;

sub load_networks {
	my $path = Irssi::get_irssi_dir . "/webirc.auth";
	if (open(my $fh, "<", $path)) {
		my $tag;
		while (<$fh>) {
			if (/^[#;]/) {
				next;
			} elsif (/^(\w+)$/) {
				$networks{$tag = $1} = {};
			} elsif (/^\s+(\w+?)=(.+)$/) {
				$networks{$tag}{$1} = $2;
			} else {
				warn "webirc.auth:$.: parse error: $_";
			}
		}
		close($fh);
	}
}

Irssi::signal_add_last("server connected" => sub {
	my ($server) = @_;
	my $tag = lc $server->{tag};
	if (defined $networks{$tag}) {
		my %d = %{$networks{$tag}};
		if (exists $d{host} and exists $d{pass} and exists $d{ipaddr}) {
			$server->print("", "Setting $d{host} as hostname");
			$server->send_raw_now("WEBIRC $d{pass} cgiirc $d{host} :$d{ipaddr}");
		}
	}
});

load_networks();
