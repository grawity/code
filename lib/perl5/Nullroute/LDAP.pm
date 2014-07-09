# Miscellaneous utility functions for my LDAP scripts.

package Nullroute::LDAP;
use base "Exporter";
use Nullroute::Lib;

@EXPORT = qw(
	ldap_check
);

sub ldap_format_error {
	my ($res, $dn) = @_;

	utf8::decode($res->error);
	my $text = "LDAP error: ".$res->error;
	$text .= "\n\tcode: ".$res->error_name if $::debug;
	$text .= "\n\tfailed: ".$dn            if $dn;
	$text .= "\n\tmatched: ".$res->dn      if $res->dn;
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
