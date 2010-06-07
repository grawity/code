#!/usr/bin/perl
# Sets up symlinks in ~/bin to my scripts.
# Internal use only.
use warnings;

my $BIN = "$ENV{HOME}/bin";
my $SRC = "$ENV{HOME}/code";

chdir $SRC or die;

sub cc {
	my $out = shift;
	my @in = @_;
	print "compile: ", (join " ", @in), " --> $BIN/$out\n";
	system "gcc", "-o", "$BIN/$out", @in;
}
sub ln {
	my ($link, $target) = @_;
	$target =~ s/\*/$link/g;
	$link = "$BIN/$link";
	$target = "../code/$target";
	print "symlink: $link --> $target\n";
	-f $link and unlink $link;
	symlink $target, $link;
}

ln tweet => "*.pl";
ln gist => "*.pl";
ln getnetrc => "tools/*.pl";
ln getpaste => "*.pl";
ln rdt => "*.php";
ln settermtitle => "tools/*.pl";
ln shorten => "*-isgd";
ln sprunge => "*";
ln sshupdate => "*.sh";
ln urlencode => "tools/*.pl";
ln useshare => "tools/*";

cc bgrep => "tools/bgrep.c";
cc args => "tools/args.c";
