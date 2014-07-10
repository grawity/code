# Miscellaneous utility functions for my LDAP scripts.

package Nullroute::LDAP;
use base "Exporter";
use Nullroute::Lib;

@EXPORT = qw(
	ldap_check
);

sub ldap_format_error {
	my ($res, $dn) = @_;

	my $text = "LDAP error: ".$res->error;
	$text .= "\n * error code: ".$res->error_name if $::debug;
	$text .= "\n * failed entry: ".$dn            if $dn;
	$text .= "\n * matched entry: ".$res->dn      if $res->dn;
	return $text;
}

sub ldap_check {
	my ($res, $dn) = @_;

	if ($res->is_error) {
		my $text = ldap_format_error($res, $dn);
		_die($text);
	}
}

1;
