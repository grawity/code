#!/usr/bin/env perl
# Capture a window or entire screen to a PNG file, output filename.
#
# Uses GNOME Shell's screenshot functionality, which means decorations
# and window shadows get captured correctly (as transparent PNG).

use feature qw(say state switch);
no if $] >= 5.017011, warnings => qw(experimental::smartmatch);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec::Functions qw(rel2abs);
use Getopt::Long qw(:config no_ignore_case);
use Net::DBus;
use POSIX qw(strftime :sys_wait_h);

sub get_userdir {
	my $name = shift;
	my @confdirs =
		$ENV{XDG_CONFIG_HOME} // $ENV{HOME}."/.config",
		split(/:/, $ENV{XDG_CONFIG_DIRS} // "");
	my ($conffile) = grep {-e} map {$_."/user-dirs.dirs"} @confdirs;
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
	$userdir //= $ENV{HOME}."/".ucfirst($name);
	return $userdir;
}

sub Shell {
	Net::DBus->session
	->get_service("org.gnome.Shell")
	->get_object(shift // "/org/gnome/Shell")
}

sub Notifications {
	Net::DBus->session
	->get_service("org.freedesktop.Notifications")
	->get_object("/org/freedesktop/Notifications")
}

sub notify {
	state $id = 0;
	my ($summary, %opts) = @_;

	$id = Notifications->Notify(
		$opts{app} // "Screenshot",
		$id,
		$opts{icon} // "document-send",
		$summary,
		$opts{body},
		$opts{actions} // [],
		$opts{hints} // {},
		$opts{timeout} // 1*1000);
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

my $ShellScreenshot = Shell("/org/gnome/Shell/Screenshot");

for ($mode) {
	when ('area') {
		Shell->ShowOSD({icon => "camera-photo-symbolic",
				label => "Select area"});
		my ($x, $y, $w, $h) = eval {$ShellScreenshot->SelectArea()}
		or die "Shell->SelectArea failed\n";
		$ShellScreenshot->ScreenshotArea($x, $y, $w, $h, $flash, $file)
		or die "Shell->ScreenshotArea failed\n";
	}
	when ('fullscreen') {
		$ShellScreenshot->Screenshot($cursor, $flash, $file)
		or die "Shell->Screenshot failed\n";
	}
	when ('window') {
		$ShellScreenshot->ScreenshotWindow($frame, $cursor, $flash, $file)
		or die "Shell->ScreenshotWindow failed\n";
	}
}

$file = rel2abs($file, get_userdir("pictures"));

if (! -f $file) {
	notify("Screenshot failed.",
		icon => "error",
		hints => {
			category => "transfer",
		});
	exit 1;
}

say $file;

my $upload_pid;
my $upload_output;

local $SIG{CHLD} = sub {
	my $pid = waitpid(-1, WNOHANG);
	if ($pid == $upload_pid) {
		$upload_pid = 0;
	}
};

$upload_pid = open(my $upload_proc, "-|") || do {
	open(STDERR, ">&", \*STDOUT);
	exec("imgur", $file);
};

while ($upload_pid) {
	notify("Screenshot captured",
		body => "Uploading...",
		hints => {
			category => "transfer",
		});
	sleep 1;
}

$upload_output = do { local $/; <$upload_proc> };

print $upload_output;
chomp $upload_output;

if ($? == 0) {
	notify("Screenshot uploaded",
		body => $upload_output,
		hints => {
			category => "transfer.complete",
		});
} else {
	notify("Screenshot upload failed",
		body => $upload_output,
		icon => "error",
		hints => {
			category => "transfer.error",
		});
}
