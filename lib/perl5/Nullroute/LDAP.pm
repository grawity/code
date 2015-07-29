# Miscellaneous utility functions for my LDAP scripts.
# vim: ts=4:sw=4:et:
package Nullroute::LDAP;
use base "Exporter";
use Nullroute::Lib;

@EXPORT = qw(
    ldap_read_attr
    ldap_cas_attr
    ldap_increment_attr
    ldap_check
);

sub ldap_read_attr {
    my ($conn, $dn, $attr) = @_;
    my $res;

    $res = $conn->search(base => $dn,
                         scope => "base",
                         filter => "(objectClass=*)",
                         attrs => [$attr]);
    ldap_check($res);

    if ($res->count > 0) {
        return $res->entry(0)->get_value($attr);
    } else {
        return undef;
    }
}

sub ldap_cas_attr {
    my ($conn, $dn, $attr, $old, $new) = @_;
    my $res;

    $res = $conn->modify($dn,
        delete => { $attr => $old },
        add => { $attr => $new },
    );
    ldap_check($res, $dn,
        ["LDAP_NO_SUCH_ATTRIBUTE",
         "LDAP_TYPE_OR_VALUE_EXISTS"]);

    return !$res->is_error;
}

sub ldap_increment_attr {
    my ($conn, $dn, $attr, $incr) = @_;
    my $done;
    my $val;

    $incr ||= 1;
    $done = false;
    until ($done) {
        _debug("fetching $attr");
        $val = ldap_read_attr($conn, $dn, $attr);
        _debug("fetched '$val', swapping");
        $done = ldap_cas_attr($conn, $dn, $attr, $val, $val+$incr);
        _debug($done ? "finished" : "retrying");
    }
    return $val+$incr;
}

sub ldap_format_error {
    my ($res, $dn) = @_;

    my $text = "LDAP error: ".$res->error;
    utf8::decode($text);
    $text .= "\n * error code: ".$res->error_name if $::debug;
    $text .= "\n * failed entry: ".$dn            if $dn;
    $text .= "\n * matched entry: ".$res->dn      if $res->dn;
    my $i = 1;
    while ($::debug) {
        my ($pkg, $file, $line, $subr) = caller($i++);
        if (!$pkg) {
            last;
        }
        $text .= "\n * stack: $pkg | $file:$line | $subr";
    }
    return $text;
}

sub ldap_check {
    my ($res, $dn, $ignore) = @_;

    return if !$res->is_error;

    utf8::decode($dn);
    if (ref $ignore eq 'ARRAY' && grep {$res->error_name eq $_} @$ignore) {
        _debug("ignoring ".$res->error_name.($dn ? " for $dn" : ""));
        return;
    }
    my $text = ldap_format_error($res, $dn);
    _die($text);
}

1;
