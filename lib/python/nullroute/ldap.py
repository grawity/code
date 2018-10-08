import ldap3
import ldap3.protocol.rfc4527
from ldap3.utils.ciDict import CaseInsensitiveDict
import ssl

LDAP_CONTROL_POSTREAD = "1.3.6.1.1.13.2"

LDAP_FEATURE_MODIFY_INCREMENT = "1.3.6.1.1.14"

def connect_gssapi(host):
    serv = ldap3.Server(host,
                        tls=ldap3.Tls(validate=ssl.CERT_REQUIRED),
                        get_info="DSA")
    conn = ldap3.Connection(serv,
                            authentication="SASL",
                            sasl_mechanism="GSSAPI")
    conn.open()
    if not conn.start_tls():
        raise Exception("start_tls failed", conn.result)
    if not conn.bind():
        raise Exception("bind failed", conn.result)
    return conn

def _has_control(conn, oid):
    return oid in {c[0] for c in conn.server.info.supported_controls}

def _has_feature(conn, oid):
    return oid in {c[0] for c in conn.server.info.supported_features}

def read_attr(conn, dn, attr, raw=False):
    if not conn.search(dn, "(objectClass=*)",
                       search_scope="BASE",
                       attributes=[attr]):
        raise Exception("search failed", conn.result)
    attr = conn.entries[0][attr]
    return attr.raw_values if raw else attr.values

def increment_attr(conn, dn, attr, incr=1):
    # optimization: RFC 4525 Modify-Increment + RFC 4527 Post-Read
    if _has_control(conn, LDAP_CONTROL_POSTREAD) and \
       _has_feature(conn, LDAP_FEATURE_MODIFY_INCREMENT):
        # this is far uglier than the Perl version already
        postread_ctrl = ldap3.protocol.rfc4527.post_read_control([attr])
        res = conn.modify(dn,
                          {attr: [(ldap3.MODIFY_INCREMENT, incr)]},
                          controls=[postread_ctrl])
        if not res:
            raise Exception("modify-increment failed", conn.result)
        res = conn.result["controls"][LDAP_CONTROL_POSTREAD]["value"]["result"]
        res = CaseInsensitiveDict(res)
        return res[attr][0]

    done = False
    wait = 0
    while not done:
        val = read_attr(conn, dn, attr)
        val = int(val[0]) if val else 0
        # _cas_attr
        done = conn.modify(dn,
                           {attr: [(ldap3.MODIFY_DELETE, val),
                                   (ldap3.MODIFY_ADD, val + incr)]})
        if not done:
            Core.debug("modify failed: %r", conn.result)
            wait += 1
            time.usleep(0.05 * 2**int(rand(wait)))
    return val+incr
