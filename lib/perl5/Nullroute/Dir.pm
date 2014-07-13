package Nullroute::Dir;
use base "Exporter";
use File::Spec::Functions;
use Nullroute::Lib qw(_debug);

our @EXPORT = qw(
	xdg_config
	xdg_cache
	xdg_data
	xdg_runtime
	xdg_userdir
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

sub _xdg_userdir {
	my ($env) = @_;

	my $conf = xdg_config("user-dirs.dirs");

	if (open(my $file, "<", $conf)) {
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
	} else {
		_debug("could not open \"$conf\": $!");
	}

	return undef;
}

sub xdg_userdir {
	my ($name, $suffix) = @_;
	my ($env, $fallback);

	$name = uc($name);

	if ($name =~ /^public(?:share)?$/i) {
		$env = "XDG_PUBLICSHARE_DIR";
		$fallback = "Public";
	} else {
		$env = "XDG_".uc($name)."_DIR";
		$fallback = ucfirst($name);
	}

	my $base = _xdg_userdir($env) // catdir($ENV{HOME}, $fallback);

	length($suffix) ? catfile($base, $suffix) : $base;
}

1;
