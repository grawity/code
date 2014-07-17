# boilerplate for scripts that only need the logging functions of Lib.pm

BEGIN {
	if (eval {require Nullroute::Lib}) {
		Nullroute::Lib->import(qw(_debug _warn _err _die));
	} else {
		our ($arg0, $warnings, $errors);
		$::arg0 = (split m!/!, $0)[-1];
		$::debug = !!$ENV{DEBUG};
		sub _debug { warn "debug: @_\n" if $::debug; }
		sub _warn  { warn "warning: @_\n"; ++$::warnings; }
		sub _err   { warn "error: @_\n"; ! ++$::errors; }
		sub _die   { _err(@_); exit 1; }
	}
}
