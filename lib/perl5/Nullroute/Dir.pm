package Nullroute::Dir;
use base "Exporter";
use File::Spec::Functions;
use Nullroute::Lib qw(_debug);

our @EXPORT = qw(
	xdg_config
	xdg_cache
	xdg_data
	xdg_runtime

	xdg_configs
	find_first_file

	xdg_userdir
);

my %XDG_FALLBACK = (
	DOWNLOAD    => "Downloads",
	PUBLICSHARE => "Public",
);

sub _xdg_basedir {
	my ($env, $fallback, $suffix) = @_;

	my $base = $ENV{$env} // catdir($ENV{HOME}, $fallback);

	length($suffix) ? catfile($base, $suffix) : $base;
}

sub xdg_cache   { _xdg_basedir("XDG_CACHE_HOME",  ".cache",       @_); }
sub xdg_config  { _xdg_basedir("XDG_CONFIG_HOME", ".config",      @_); }
sub xdg_data    { _xdg_basedir("XDG_DATA_HOME",   ".local/share", @_); }
sub xdg_runtime { _xdg_basedir("XDG_RUNTIME_DIR", xdg_cache(@_),  @_); }

sub _xdg_basedirs {
	my ($local_func, $sys_env, $sys_fallback, $suffix) = @_;

	my @sys_base = split(/:/, $ENV{$sys_env} // $sys_fallback);
	my @paths =
		$local_func ? $local_func->($suffix) : (),
		map {catfile($_, $suffix)} @sys_base;

	_debug("checking for {@paths}");
	grep {-e} @paths;
}

sub xdg_configs { _xdg_basedirs(\&xdg_config, "XDG_CONFIG_DIRS", "/etc/xdg", @_); }

sub _xdg_userdir {
	my ($env) = @_;

	my ($conf) = xdg_configs("user-dirs.dirs");

	if (!$conf) {
		_debug("could not find 'user-dirs.dirs' in any XDG config path");
	} elsif (!open(my $file, "<", $conf)) {
		_debug("could not open \"$conf\": $!");
	} else {
		_debug("trying to find \$$env in \"$conf\"");
		while (<$file>) {
			next unless /^\Q$env\E=(.+)$/;
			_debug("found value: <$1>");
			my $path = $1;
			$path =~ s/^"(.+)"$/$1/;
			$path =~ s!^\$HOME/!$ENV{HOME}/!;
			_debug("expanded to: <$path>");
			last if $path !~ m!^/!;
			return $path;
		}
		close($file);
		_debug("no results, giving up");
	}

	return undef;
}

sub xdg_userdir {
	my ($name, $suffix) = @_;

	my $name = uc($name);
	my $env = "XDG_".$name."_DIR";
	my $fallback = $XDG_FALLBACK{$name} // ucfirst($name);
	my $base = _xdg_userdir($env) // catdir($ENV{HOME}, $fallback);

	length($suffix) ? catfile($base, $suffix) : $base;
}

sub find_first_file {
	my (@paths) = @_;

	my $vendor = "nullroute.eu.org";
	my $fallback;

	for (@paths) {
		_debug("looking for '$_'");
		s!^~/!$ENV{HOME}/!;
		s!^cache:/!xdg_cache()."/"!e;
		s!^cache:!xdg_cache($vendor)."/"!e;
		s!^config:/!xdg_config()."/"!e;
		s!^config:!xdg_config($vendor)."/"!e;
		s!^data:/!xdg_data()."/"!e;
		s!^data:!xdg_data($vendor)."/"!e;
		_debug("expanded to '$_'");
		if (-e $_) {
			_debug("found '$_'");
			return $_;
		}
		$fallback = $_;
	}
	_debug("returning fallback '$_'");
	return $fallback;
}

1;
