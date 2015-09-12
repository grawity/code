# Miscellaneous utility functions for my LDAP scripts.
# vim: ts=4:sw=4:et:
package Nullroute::LDAP;
use base "Exporter";
use Net::LDAP::Constant (
    "LDAP_CONTROL_ASSERTION",
    "LDAP_CONTROL_POSTREAD",
    "LDAP_FEATURE_MODIFY_INCREMENT",
);
use Net::LDAP::Control::Assertion;
use Net::LDAP::Control::PostRead;
use Nullroute::Lib;
use Time::HiRes qw(usleep);

@EXPORT = qw(
    ldap_read_attr
    ldap_cas_attr
    ldap_increment_attr

    ldap_check
);

# Atomic operations

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
    my $control = [];
    my $res;

    if ($old eq $new) {
        _debug("ignoring no-op update '$old' -> '$old'");
        return 1;
    }

    # optimization: RFC 4528 Assertion
    # (not sure if useful; perhaps if used with 'replace'?)

    if ($conn->root_dse->supported_control(LDAP_CONTROL_ASSERTION)) {
        _debug("using Assertion control");
        $control = [
            Net::LDAP::Control::Assertion->new("($attr=$old)"),
        ];
    }

    # atomically delete old value and add the new one
    #
    # (NOTE: actually not sure if LDAP *guarantees* atomicity within the same
    # Modify op, but if all clients cooperate, this should be good enough)

    $res = $conn->modify($dn,
        changes => [
            delete => [ $attr => $old ],
            add    => [ $attr => $new ],
        ],
        control => $control,
    );
    ldap_check($res, $dn, ["LDAP_NO_SUCH_ATTRIBUTE", "LDAP_ASSERTION_FAILED"]);

    return !$res->is_error;
}

sub ldap_increment_attr {
    my ($conn, $dn, $attr, $incr) = @_;
    my $res;
    my $val;
    my $done;
    my $wait;

    $incr ||= 1;
    $done = false;

    # optimization: RFC 4525 Modify-Increment + RFC 4527 Post-Read

    if ($conn->root_dse->supported_control(LDAP_CONTROL_POSTREAD)
        && $conn->root_dse->supported_feature(LDAP_FEATURE_MODIFY_INCREMENT))
    {
        _debug("using Modify-Increment extension");
        $res = $conn->modify($dn,
            increment => { $attr => $incr },
            control => [
                Net::LDAP::Control::PostRead->new(attrs => [$attr]),
            ],
        );
        ldap_check($res);
        if ($res->control(LDAP_CONTROL_POSTREAD)) {
            return $res->control(LDAP_CONTROL_POSTREAD)->entry->get_value($attr);
        } else {
            _debug("increment failed, using modify loop");
        }
    }

    # manual compare-and-swap

    $wait = 0;

    until ($done) {
        _debug("fetching $attr");
        $val = ldap_read_attr($conn, $dn, $attr);
        _debug("fetched '$val', swapping");
        $done = ldap_cas_attr($conn, $dn, $attr, $val, $val+$incr);
        _debug($done ? "finished" : "retrying");
        if (!$done) {
            usleep(0.05 * 2**int(rand(++$wait)));
        }
    }
    return $val+$incr;
}

# Result error checking

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

    if (!$res->is_error) {
        return 1;
    }
    utf8::decode($dn);
    if (ref $ignore eq 'ARRAY' && grep {$res->error_name eq $_} @$ignore) {
        _debug("ignoring ".$res->error_name.($dn ? " for $dn" : ""));
        return 0;
    }
    my $text = ldap_format_error($res, $dn);
    _die($text);
}

1;
