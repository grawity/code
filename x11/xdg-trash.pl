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
use File::Spec::Functions;
use Getopt::Long qw(:config bundling no_ignore_case);
use POSIX qw(strftime);

BEGIN {
	if (eval {require Nullroute::Lib}) {
		Nullroute::Lib->import(qw(_debug _info _warn _err _die));
	} else {
		our ($arg0, $warnings, $errors);
		$::debug = !!$ENV{DEBUG};
		sub _debug { warn "debug: @_\n" if $::debug; }
		sub _info  { print "@_\n"; }
		sub _warn  { warn "warning: @_\n"; ++$::warnings; }
		sub _err   { warn "error: @_\n"; ++$::errors; }
		sub _die   { _err(@_); exit 1; }
	}
}

our $INTERACTIVE = 0;
our $VERBOSE = 1;

our $DO_PRINT_PATH = 0;

my $now = strftime("%Y-%m-%dT%H:%M:%S", localtime);

my $home_trash = ($ENV{XDG_DATA_HOME} // $ENV{HOME}."/.local/share") . "/Trash";

sub verbose {
	goto &_info if $::debug;
	print "\r\033[K", @_, "\n" if $VERBOSE;
}

sub confirm {
	print "$::arg0: ", shift, " "; $|++; <STDIN> =~ /^y/i;
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
	my $b = basename($path);
	my $d = dirname($path);
	my $rd = realpath($d);
	_debug("abs: dir='$d' realdir='$rd' base='$b'");
	return $rd."/".$b;
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
	for ($trash_dir, "$trash_dir/info", "$trash_dir/files") {
		next     if -d $_;
		return 0 if -e $_;
		make_path($_, {mode => 0700}) or return 0;
	}
	return 1;
}

=item xdev_move($source, $dest) -> $success

Copy a file or directory $source to $dest recursively and delete the originals.

=cut

sub xdev_move {
	my ($source, $dest) = @_;
	my @opt;
	_debug("xdev_move: source='$source'");
	_debug("xdev_move: dest='$dest'");
	verbose("Copying '$source' to \$HOME...");
	@opt = qw(-a -H -A -X);
	$ENV{DEBUG} and push @opt, qw(-v -h);
	system("rsync", @opt, "$source", "$dest") == 0
		or return 0;
	verbose("Removing '$source' after copying...");
	@opt = qw(-r -f);
	$ENV{DEBUG} and push @opt, qw(-v);
	system("rm", @opt, $source) == 0
		or return 0;
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
	while ($i < 1000) {
		$name = $i ? "$base-$i" : $base;
		$info_path = "$trash_dir/info/$name.trashinfo";
		if (sysopen($fh, $info_path, O_WRONLY|O_CREAT|O_EXCL)) {
			_debug("found free info_path='$info_path'");
			return ($name, $fh, $info_path);
		} elsif ($! == EEXIST) {
			_debug("'$name.trashinfo' already exists, trying next...")
				if ($i % 25 == 0);
		} else {
			_err("cannot create '$info_path' ($!)");
			return undef;
		}
		++$i;
	}
	_debug("giving up after $i failures");
	_err("cannot create .trashinfo file (too many items named '$base')");
	return undef;
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

	_debug("trying to find trash for path='$orig_path'");
	my $fdev = dev($orig_path);
	while (!defined $fdev) {
		$orig_path = dirname($orig_path);
		_debug("...path not found, using parent='$orig_path'");
		$fdev = dev($orig_path);
	}

	my $hdev = dev($home_trash);
	if (!defined $fdev) {
		return undef;
	} elsif ($fdev == $hdev) {
		return $home_trash;
	} else {
		my $root = find_root($orig_path);
		my $dir = catdir($root, ".Trash");
		if (-d $dir && ! -l $dir && -k $dir && ensure("$dir/$<")) {
			return "$dir/$<";
		}
		$dir = catdir($root, ".Trash-$<");
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
		_err("not found: '$path'");
		return;
	}
	if ($INTERACTIVE) {
		confirm("Kill file <$path>?") || return;
	}
	my $orig_path = my_abs_path($path);
	_debug("orig_path='$orig_path'");
	my $trash_dir = find_trash_dir($orig_path);
	_debug("trash_dir='$trash_dir'");
	ensure($trash_dir);
	my ($name, $info_fh, $info_name) = create_info($trash_dir, $orig_path);
	if (!$info_fh) {
		_err("failed to move '$path' to trash");
		return;
	}
	write_info($info_fh, $orig_path);
	my $trashed_path = "$trash_dir/files/$name";
	if (dev($orig_path) == dev($trash_dir)) {
		if (rename($orig_path, $trashed_path)) {
			verbose("Trashed '$path'");
		} else {
			unlink($info_name);
			_die("failed to rename '$path': $!");
		}
	} else {
		if (xdev_move($orig_path, $trashed_path)) {
			verbose("Trashed '$path' to \$HOME");
		} else {
			unlink($info_name);
			_die("failed to copy '$path' to '$trash_dir'");
		}
	}
	close($info_fh);
}

GetOptions(
	'path'		=> \$DO_PRINT_PATH,
	'i|interactive!'=> \$INTERACTIVE,
	'r|R|recursive'	=> sub { },
	'f|force'	=> sub { },
	'v|verbose!'	=> \$VERBOSE,
) or die;

if (@ARGV) {
	if ($DO_PRINT_PATH) {
		say find_trash_dir(my_abs_path($_)) // "(not found?)" for @ARGV;
	} else {
		trash($_) for @ARGV;
	}
} else {
	_err("no files given");
}

exit(!!$::errors);
