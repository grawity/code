#!/usr/bin/env perl
# trash - move files into XDG Trash
use v5.10;
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

=item my_abs_path($path)

Canonicalize symlinks and relative paths.
If $path itself is a symlink, do not canonicalize it.

=cut

sub my_abs_path {
	my ($path) = @_;
	realpath(dirname($path))."/".basename($path);
}

=item find_root($abs_path)

Find the root directory of the filesystem $path is in.

Does not currently work with bind-mounted files; returns the mountpoint's parent.

=cut

sub find_root {
	my ($path) = @_;
	my $fdev = dev($path);
	return undef if !defined $fdev;
	my $prev = $path;
	while ($path ne "/") {
		$prev = $path;
		$path = dirname($path);
		return $prev if dev($path) != $fdev;
	}
	return $path;
}

=item ensure($trash_dir)

Recursively mkdir $trash_dir/{files,info} if necessary.

=cut

sub ensure {
	my ($trash_dir) = @_;
	for ("$trash_dir/info", "$trash_dir/files") {
		unless (-d) {
			make_path($_, {mode => 0700}) or return 0;
		}
	}
	return 1;
}

=item create_info($trash_dir, $orig_path) -> ($name, $fh, $path)

Securely create a .trashinfo file in $trash_dir with a basename similar
to that of $orig_path; return the new basename, a writable filehandle,
and for convenience the full path to the file.

=cut

sub create_info {
	my ($trash_dir, $orig_path) = @_;
	my $base = basename($orig_path);
	my $i = 0;
	my ($name, $fh, $info_path);
	while (1) {
		$name = $i ? "$base-$i" : $base;
		$info_path = "$trash_dir/info/$name.trashinfo";
		if (sysopen($fh, $info_path, O_WRONLY|O_CREAT|O_EXCL)) {
			return ($name, $fh, $info_path);
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

=item write_info($fh, $orig_path)

Write the [Trash Info] block for $orig_path to a filehandle.

=cut

sub write_info {
	my ($info_fh, $orig_path) = @_;
	print $info_fh "[Trash Info]\n";
	print $info_fh "Path=$orig_path\n";
	print $info_fh "DeletionDate=$now\n";
}

=item find_trash_dir($orig_path)

Find the best trash directory to use, according to XDG Trash Dir spec.

 * $home_trash if same device
 * $root/.Trash/$UID if checks pass
 * $root/.Trash-$UID if exists or can create
 * $home_trash otherwise

=cut

sub find_trash_dir {
	my ($orig_path) = @_;
	ensure($home_trash);
	my $fdev = dev($orig_path);
	my $hdev = dev($home_trash);
	if (!defined $fdev) {
		return undef;
	} elsif ($fdev == $hdev) {
		return $home_trash;
	} else {
		my $root = find_root($orig_path);
		my $dir = "$root/.Trash";
		if (-d $dir && ! -l $dir && -k $dir && ensure("$dir/$<")) {
			return "$dir/$<";
		}
		$dir = "$root/.Trash-$<";
		if (-d $dir || ensure($dir)) {
			return $dir;
		}
	}
	return $home_trash;
}

=item trash($path)

Create a trashinfo file in the appropriate trash directory, then move
actual $path there. If move fails, delete trashinfo and explode.

=cut

sub trash {
	my ($path) = @_;
	if (!lstat($path)) {
		warn "trash: Not found: '$path'\n";
		return;
	}
	my $orig_path = my_abs_path($path);
	my $trash_dir = find_trash_dir($orig_path);
	print "DEBUG: trash_dir = $trash_dir\n" unless $trash_dir eq $home_trash;
	ensure($trash_dir);
	my ($name, $info_fh, $info_name) = create_info($trash_dir, $orig_path);
	write_info($info_fh, $orig_path);
	close($info_fh);
	if (dev($orig_path) == dev($trash_dir)) {
		if (rename($orig_path, "$trash_dir/files/$name")) {
			verbose("Trashed '$path'\n");
		} else {
			unlink($info_name);
			die "trash: Rename of '$path' failed: $!\n";
		}
	} else {
		unlink($info_name);
		warn "trash: Skipped: '$path' (cannot trash to different filesystem yet)\n";
	}
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
