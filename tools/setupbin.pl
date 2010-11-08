#!/usr/bin/perl
# Sets up symlinks in ~/bin to my scripts.
# Internal use only.
use warnings;
use strict;
use File::stat;
use File::Spec;
use File::Spec::Functions;
use List::Util qw[min];

my $BIN = $ENV{MY_BIN} // "$ENV{HOME}/bin";
my $LIB = $ENV{MY_LIB} // "$ENV{HOME}/lib";
my $SRC = $ENV{MY_SRC} // "$ENV{HOME}/code";
my $BASE;

chdir $SRC or die;

sub mtime($) {
	my $stat = stat(shift);
	return defined $stat? $stat->[9] : 0;
}

sub cc {
	my ($out, @in) = @_;
	$out = catfile($BASE, $out);
	if (mtime $out < min(map {mtime $_} @in)) {
		print "compile: ", (join " ", @in), " --> $out\n";
		system "gcc", "-o", $out, @in;
	}
	else {
		print "skip compile: $out\n";
	}
}
sub ln {
	my ($link, $target, %opts) = @_;
	$target =~ s/\*/$link/g;
	$link = catfile($BASE, $link);
	if ($opts{relative} // 1) {
		$target = File::Spec->abs2rel(catfile($SRC, $target), $BASE);
	}
	print "symlink: $link --> $target\n";
	-l $link and unlink $link;
	symlink $target, $link;
}

sub which {
	my ($name) = @_;
	grep {-x catfile($_, $name)} File::Spec->path;
}

-d $BIN || mkdir $BIN;
-d $LIB || mkdir $LIB;

$BASE = $BIN;
cc args => "tools/args.c";
cc bgrep => "tools/bgrep.c";
#cc logwipe => "tools/wipe.c";

ln dotrc => "tools/*";
ln gist => "*.pl";
ln getkeyring => "devel/*";
ln getnetrc => "tools/*.pl";
ln getpaste => "*.pl";
ln getsession => "tools/*.sh";
ln motd => "*";
ln rdt => "*.php";
ln rwhod => "useless/rwho/*.pl";
ln setupbin => "tools/*.pl";
ln shorten => "*-isgd";
ln sprunge => "*";
ln sshupdate => "*";
ln urlencode => "tools/*.pl";
ln useshare => "tools/*";

if (which "krb5-config") {
	my $krb = `krb5-config --version`;
	my @make = ("make", "-C", "pklist");
	$krb =~ /^heimdal / && push @make, "D=-DHEIMDAL";
	if (system @make) {
		ln pklist => "pklist/pklist";
	}
}

if (!which "python2") {
	ln python2 => which "python", relative => 0;
}

$BASE = $LIB;
ln "kc.bash" => "lib/*";
ln "libident.php" => "lib/*";
