#!/usr/bin/env perl
# Tool to create relative symlinks.
#
# (c) 2010 <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

use warnings;
use strict;

use Getopt::Long qw(:config bundling no_ignore_case);
use File::Basename;
use File::Spec;

my $force = 0;
my $verbose = 0;
my $dest;

sub usage {
	my $me = basename($0);
	print STDERR "usage: $me [-f] TARGET LINKNAME\n";
	print STDERR "       $me [-f] TARGET... DIRECTORY\n";
	exit 2;
}

sub do_link {
	my ($target, $link) = @_;
	$verbose && print "`$link' -> `$target'\n";
	if (-l $link or -e $link) {
		if ($force) {
			unlink($link);
			symlink($target, $link) or warn "$!";
		} else {
			warn "$link: already exists\n";
		}
	} else {
		symlink($target, $link) or warn "$!";
	}
}

GetOptions(
	"f|force" => \$force,
	"t|target-directory=s" => \$dest,
	"v|verbose" => \$verbose,
) or usage;

if (!defined $dest) {
	if (scalar(@ARGV) > 1) {
		$dest = pop(@ARGV);
	} else {
		$dest = ".";
	}
}

if (!@ARGV) {
	usage;
}

if (-d $dest) {
	# target [target...] dirname
	for my $target (@ARGV) {
		my $reltarget = File::Spec->abs2rel($target, $dest);
		my $link = File::Spec->catfile($dest, basename($target));
		do_link($reltarget, $link);
	}
} elsif (scalar(@ARGV) > 1) {
	# target target... name
	die "error: target is not a directory\n";
} else {
	# target name
	my $target = pop(@ARGV);
	my $reltarget = File::Spec->abs2rel($target, dirname($dest));
	do_link($reltarget, $dest);
}
