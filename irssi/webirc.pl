# vim: ft=perl
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
use Data::Dumper;

$VERSION = "0.7";
%IRSSI = (
	name        => 'webirc.pl',
	description => 'Implements WEBIRC authentication for UnrealIRCd',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
);

my %networks;

sub load_networks {
	my $path = Irssi::get_irssi_dir . "/webirc.auth";
	if (open(my $fh, "<", $path)) {
		my ($tag, $key, $value);
		while (<$fh>) {
			if (/^[#;]/) {
				next;
			} elsif (/^(\w+)$/) {
				$tag = $1;
				$networks{$tag} = {};
				print "tag = $1";
			} elsif (/^\s+(\w+?)=(.+)$/) {
				$networks{$tag}{$1} = $2;
				print "tag/$tag/$1 = $2";
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
