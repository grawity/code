import ldap
import ldap.controls.readentry
from nullroute.core import Core

OID_LDAP_CONTROL_POSTREAD = b"1.3.6.1.1.13.2"
OID_LDAP_FEATURE_MODIFY_INCREMENT = b"1.3.6.1.1.14"

class CaseInsensitiveDict(dict):
    def __init__(self, *args, **kwargs):
        tmp = dict(*args, **kwargs)
        tmp = {k.lower(): v for k, v in tmp.items()}
        super().__init__(tmp)

    def __getitem__(self, key):
        return super().__getitem__(key.lower())

    def __setitem__(self, key, value):
        super().__setitem__(key.lower(), value)

def connect_gssapi(url):
    conn = ldap.initialize(url)
    if not url.startswith(("ldaps://", "ldapi://")):
        conn.start_tls_s()
    conn.sasl_interactive_bind_s("", ldap.sasl.gssapi())
    return conn

def read_attr(conn, dn, attr, raw=False):
    attrs = conn.read_s(dn, attrlist=[attr])
    values = CaseInsensitiveDict(attrs)[attr]
    if not raw:
        values = [v.decode() for v in values]
    return values

def increment_attr(conn, dn, attr, incr=1, use_increment=True):
    if use_increment:
        # TODO: this needs to be cached
        rootDSE = conn.read_rootdse_s()
        if OID_LDAP_CONTROL_POSTREAD in rootDSE["supportedControl"] and \
           OID_LDAP_FEATURE_MODIFY_INCREMENT in rootDSE["supportedFeatures"]:
            incr = str(incr).encode()
            ctrl = ldap.controls.readentry.PostReadControl(attrList=[attr])
            res = conn.modify_ext_s(dn,
                                    [(ldap.MOD_INCREMENT, attr, incr)],
                                    serverctrls=[ctrl])
            for outctrl in res[3]:
                if outctrl.controlType == ctrl.controlType:
                    values = CaseInsensitiveDict(outctrl.entry)[attr]
                    return int(values[0])
    
    done = False
    wait = 0
    while not done:
        old_val = read_attr(conn, dn, attr, raw=True)[0]
        new_val = str(int(old_val) + incr).encode()
        # _cas_attr
        done = conn.modify_s(dn,
                             [(ldap.MOD_DELETE, attr, old_val),
                              (ldap.MOD_ADD, attr, new_val)])
        if not done:
            Core.debug("modify failed: %r", conn.result)
            wait += 1
            time.usleep(0.05 * 2**int(rand(wait)))
    return int(new_val)
