#!/usr/bin/env perl
use warnings;
use strict;
use Cwd qw(realpath);
use Errno qw(:POSIX);
use Fcntl;
use File::Basename qw(basename dirname);
use File::Path qw(make_path);
use Getopt::Long qw(:config bundling no_ignore_case);
use POSIX qw(strftime);

our $VERBOSE = 1;

my $now = strftime("%Y-%m-%dT%H:%M:%S", localtime);

my $home_trash = "$ENV{XDG_DATA_HOME}/Trash";

sub verbose {
	print @_ if $VERBOSE;
}

sub dev {
	(lstat(shift))[0];
}

sub find_root {
	my ($path) = @_;
	$path = realpath($path);
	my $fdev = dev($path);
	return undef if !defined $fdev;
	my $prev = $path;
	print "dev($path) = $fdev\n";
	while ($path ne "/") {
		$prev = $path;
		$path = dirname($path);
		print "dev($path) = ".dev($path)."\n";
		return $prev if dev($path) != $fdev;
	}
	return $path;
}

sub ensure_dirs {
	my ($trash_dir) = @_;
	for ("$trash_dir/info", "$trash_dir/files") {
		make_path($_, mode => 0700) unless -d;
	}
}

sub create_info {
	my ($trash_dir, $orig_path) = @_;
	my $base = basename($orig_path);
	my $i = 0;
	my ($name, $fh, $info_name);
	while (1) {
		$name = $i ? "$base-$i" : $base;
		$info_name = "$trash_dir/info/$name.trashinfo";
		if (sysopen($fh, $info_name, O_WRONLY|O_CREAT|O_EXCL)) {
			return ($name, $fh, $info_name);
		} else {
			warn "trash: error: $! (for '$name')\n" unless $! == EEXIST;
			if (++$i > 100) {
				warn "trash: error: Cannot store trashinfo for $base\n";
				return undef;
			} else {
				next;
			}
		}
	}
}

sub write_info {
	my ($info_fh, $orig_path) = @_;
	print $info_fh "[Trash Info]\n";
	print $info_fh "Path=$orig_path\n";
	print $info_fh "DeletionDate=$now\n";
}

sub find_trash_dir {
	my ($orig_path) = @_;
	ensure_dirs($home_trash);
	my $fdev = dev($orig_path);
	my $hdev = dev($home_trash);
	if (!defined $fdev) {
		return undef;
	} elsif ($fdev == $hdev) {
		return $home_trash;
	} else {
		my $root = find_root($orig_path);
		if (-d "$root/.Trash" && -k _) {
			return "$root/.Trash/$<";
		}
		if (-d "$root/.Trash-$<") {
			return "$root/.Trash-$<";
		}
	}
	return $home_trash;
}

sub trash {
	my ($path) = @_;
	if (!lstat($path)) {
		warn "trash: Not found: '$path'\n";
		return;
	}
	my $orig_path = realpath($path);
	my $trash_dir = find_trash_dir($orig_path);
	print "DEBUG: trash_dir = $trash_dir\n";
	ensure_dirs($trash_dir);
	my ($name, $info_fh, $info_name) = create_info($trash_dir, $orig_path);
	write_info($info_fh, $orig_path);
	close($info_fh);
	if (rename($orig_path, "$trash_dir/files/$name")) {
		verbose("Trashed '$path'\n");
	} else {
		unlink($info_name);
		die "rename: $!\n";
	};
}

GetOptions(
	'r|R|recursive'	=> sub { },
	'f|force'	=> sub { },
	'v|verbose!'	=> \$VERBOSE,
) or die;

if (@ARGV) {
	trash($_) for @ARGV;
} else {
	warn "trash: No files given.\n";
}
