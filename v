#!/usr/bin/env perl
# v -- open vim with a specific file and position taken from primary selection

sub vmsg { warn "v: @_\n"; }
sub vdie { vmsg @_; exit 1; }

BEGIN {
	if (eval {require Nullroute::Lib}) {
		Nullroute::Lib->import(qw(_debug));
	} else {
		our ($arg0, $warnings, $errors);
		$::arg0 = (split m!/!, $0)[-1];
		sub _debug { warn "debug: @_\n" if $ENV{DEBUG}; }
	}
}

# this matches (url-decoded):
#   file:///foo/bar → /foo/bar

my $fileurlre = qr{ ^ file:// (/\S+) }mx;

# this matches URLs:

my $urlre = qr{ ^ ((?:https?|ftps?|sftp) :// \S+) }mx;

# this matches:
#   filename +lineno
#   vim filename +lineno

my $vimre = qr{ ^ (?:vim\s+)? (.+) \s+ (\+\d+) $ }mx;

# this matches:
#   filename:lineno
#   filename:lineno:garbage
#   filename:lineno,garbage
#   filename:lineno)garbage
#   filename:lineno garbage
#   filename:/regex
#   filename:/regex garbage

my $hgspecre = qr{ ^ ([^:]+) : \d+ : (\d+) : .* $ }mx;

my $specre = qr{ ^ ([^:]+) : (\d+ | /[^/]\S*) (?:[:,\)\s].*)? $ }mx;

# this matches:
#   a/foo/bar → foo/bar

my $diffpathre = qr{ ^ [a-z] / (.+) $ }mx;

# this matches:
#   ./path
#   ./path:garbage
#   /path
#   /path:garbage

my $pathre = qr{ (?<![\w/]) ([~.]? / [^:/]+) }mx;

# this matches grep context lines:
#   filename-lineno-garbage
# low priority because of possible ambiguity

my $ctxspecre = qr{ ^ ([^:]+?) - (\d+) - }mx;

# this matches:
#   File "/foo/bar", line 123,

my $pythonre = qr{ ^ File \s "(.+?)", \s line \s (\d+) }mx;

# this matches:
#   /foo/bar line 123

my $perlre = qr{ at \s (.+?) \s line \s (\d+),? }mx;



sub urldecode {
	my ($str) = @_;
	$str =~ s/%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
	return $str;
}

sub shescape {
	my ($str) = @_;
	if ($str =~ /!/) {
		$str =~ s/'/'\\''/g;
		$str = qq['$str'];
	}
	elsif ($str =~ s/[`"\$\\]/\\$&/g or $str =~ /\s/) {
		$str = qq["$str"];
	}
	return $str;
}

sub shunescape {
	# do not bother with this just yet...
	shift;
}

sub parse {
	my ($arg) = @_;
	for ($arg) {
		chomp;
		s/^\s+//;
		s/\s+$//;
		if (/$pythonre/) {
			_debug("pythonre: '$&' -> '$1' '$2'");
			my ($file, $line) = ($1, $2);
			return ($file, "+".$line);
		}
		elsif (/$fileurlre/) {
			_debug("fileurlre: '$&' -> '$1'");
			my ($file) = (urldecode($1));
			return ($file) if -e $file;
		}
		elsif (/$urlre/) {
			_debug("urlre: '$&'");
			my ($url) = ($1);
			return ($url);
		}
		elsif (-e $_) {
			_debug("exact path (-e): '$_'");
			return ($_);
		}
		elsif (/$vimre/) {
			_debug("vimre: '$&' -> '$1' '$2'");
			my ($file, $cmd) = (shunescape($1), $2);
			$file =~ s|^~/|$ENV{HOME}/|;
			return ($file, $cmd) if -e $file;
		}
		#elsif (/$hgspecre/) {
		#	_debug("hgspecre: '$&' -> '$1' '$2'");
		#	my ($file, $cmd) = ($1, $2);
		#	$cmd =~ s|^|+|;
		#	return ($file, $cmd) if -e $file;
		#}
		elsif (/$specre/) {
			_debug("specre: '$&' -> '$1' '$2'");
			my ($file, $cmd) = ($1, $2);
			$file =~ s|^~/|$ENV{HOME}/|;
			$cmd =~ s|^|+|;
			return ($file, $cmd) if -e $file;
			warn "v: matched file '$file' not found\n";
		}
		elsif (/$perlre/) {
			_debug("perlre: '$&' -> '$1' '$2'");
			my ($file, $cmd) = ($1, $2);
			$file =~ s|^~/|$ENV{HOME}/|;
			$cmd =~ s|^|+|;
			return ($file, $cmd) if -e $file;
		}
		elsif (/$diffpathre/) {
			_debug("diffpathre: '$&'");
			my ($file) = ($1);
			return ($file);
		}
		elsif (/$ctxspecre/) {
			_debug("ctxspecre: '$&' -> '$1' '$2'");
			my ($file, $cmd) = ($1, $2);
			$file =~ s|^~/|$ENV{HOME}/|;
			$cmd =~ s|^|+|;
			return ($file, $cmd) if -e $file;
		}
		elsif (/$pathre/) {
			_debug("pathre: '$&' -> '$1'");
			my ($file) = ($1);
			$file =~ s|^~/|$ENV{HOME}/|;
			return ($file) if -e $file;
		}
		elsif (/^(.+)$/m && -e $1) {
			_debug("-e: $1");
			return ($1);
		}
		else {
			_debug("nothing matched, giving up");
			return;
		}
	}
	return;
}

my $editor = $ENV{VISUAL} // $ENV{EDITOR} // "vim";
my @args = ($editor);

if (@ARGV) {
	for my $arg (@ARGV) {
		if (my @r = parse($arg)) {
			push @args, @r;
		} else {
			push @args, $arg;
		}
	}
} else {
	my $sel = `psel`;
	if ($?) {
		vdie("cannot operate without X display");
	}
	chomp($sel);
	if (!$sel) {
		vdie("selection is empty");
	}
	if (my @r = parse($sel)) {
		push @args, @r;
	} else {
		vdie("no file name in selection");
	}
}

print join(" ", map {shescape($_)} @args), "\n";
exec {$editor} @args;

vdie("could not execute '$editor': $!");
