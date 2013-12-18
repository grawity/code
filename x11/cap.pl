#!/usr/bin/env perl
# Capture a window or entire screen to a PNG file, output filename.
#
# Uses GNOME Shell's screenshot functionality, which means decorations
# and window shadows get captured correctly (as transparent PNG).

use feature qw(say switch);
no if $] >= 5.017011, warnings => qw(experimental::smartmatch);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec::Functions qw(rel2abs);
use Getopt::Long qw(:config no_ignore_case);
use Net::DBus;
use POSIX qw(strftime);

sub get_userdir {
	my $name = shift;
	my @confdirs = ($ENV{XDG_CONFIG_HOME} // $ENV{HOME}."/.config"),
			split(/:/, $ENV{XDG_CONFIG_DIRS} // ""));
	my ($conffile) = grep {-e} map {$_."/user-dirs.dirs")} @confdirs;
	my $userdir;
	if (open(my $fh, "<", $conffile)) {
		my $envname = "XDG_".uc($name)."_DIR";
		while (<$fh>) {
			next if /^#/ || /^$/;
			next unless /^\Q$envname\E="?(.+?)"?$/;
			$userdir = $1;
			$userdir =~ s|^\$HOME/|$ENV{HOME}/|;
		}
		close($fh);
	}
	return $userdir // $ENV{HOME}."/".ucfirst($name);
}

sub Shell {
	Net::DBus->session
	->get_service("org.gnome.Shell")
	->get_object(shift // "/org/gnome/Shell")
}

my $frame = 1;
my $flash = 1;
my $cursor = 0;
my $mode = 'fullscreen';
my $template = "Screenshots/%Y-%m-%d.%H%M%S.png";
my $file = undef;

GetOptions(
	'a|area'	=> sub { $mode = 'area' },
	'F|fullscreen'	=> sub { $mode = 'fullscreen' },
	'w|window'	=> sub { $mode = 'window' },
	'f|file=s'	=> sub { (undef, $template) = @_ },
	'frame!'	=> \$frame,
	'cursor!'	=> \$cursor,
	'flash!'	=> \$flash,
) or exit 2;

$file = shift @ARGV;

$file //= strftime($template, localtime);

for (dirname $file) {
	make_path unless -d;
}

my $obj = Shell("/org/gnome/Shell/Screenshot");

for ($mode) {
	when ('area') {
		my ($x, $y, $w, $h) = eval {$obj->SelectArea()}
		or die "Shell->SelectArea failed\n";
		$obj->ScreenshotArea($x, $y, $w, $h, $flash, $file)
		or die "Shell->ScreenshotArea failed\n";
	}
	when ('fullscreen') {
		$obj->Screenshot($cursor, $flash, $file)
		or die "Shell->Screenshot failed\n";
	}
	when ('window') {
		$obj->ScreenshotWindow($frame, $cursor, $flash, $file)
		or die "Shell->ScreenshotWindow failed\n";
	}
}

say rel2abs($file, get_userdir("pictures"));
