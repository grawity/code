#!/usr/bin/perl
# Sets up symlinks in ~/bin to my scripts.
# Internal use only.
use warnings;

my $BIN = "$ENV{HOME}/bin";

sub cc {
	my $out = shift;
	my @in = @_;
	print "compile: ", (join " ", @in), " --> $BIN/$out\n";
	system "gcc", "-o", "$BIN/$out", @in;
}
sub ln {
	my ($link, $target) = @_;
	$target =~ s/\*/$link/g;
	print "symlink: $BIN/$link --> ../code/$target\n";
	symlink "../code/$target", "$BIN/$link";
}

ln tweet => "*.pl";
ln gist => "*.pl";
ln getnetrc => "*.pl";
ln getpaste => "*.pl";
ln rdt => "*.php";
ln sshupdate => "*.sh";
ln urlencode => "*.pl";

cc bgrep => "tools/bgrep.c";
