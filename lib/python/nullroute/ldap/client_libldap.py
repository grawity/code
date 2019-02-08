import ldap
import ldap.controls.readentry
from nullroute.core import Core
import time

OID_LDAP_CONTROL_POSTREAD = "1.3.6.1.1.13.2"
OID_LDAP_FEATURE_MODIFY_INCREMENT = "1.3.6.1.1.14"

class CaseInsensitiveDict(dict):
    def __init__(self, *args, **kwargs):
        tmp = dict(*args, **kwargs)
        tmp = {k.lower(): v for k, v in tmp.items()}
        super().__init__(tmp)

    def __getitem__(self, key):
        return super().__getitem__(key.lower())

    def __setitem__(self, key, value):
        super().__setitem__(key.lower(), value)

def _decode_dict_values(d):
    return {k: [v.decode() for v in vs] for k, vs in d.items()}

class LdapClient():
    def __init__(self, url):
        self.conn = ldap.initialize(url)
        if not url.startswith(("ldaps://", "ldapi://")):
            self.conn.start_tls_s()

        self.rootDSE = CaseInsensitiveDict(self.conn.read_rootdse_s())
        self._controls = {v.decode() for v in self.rootDSE["supportedControl"]}
        self._features = {v.decode() for v in self.rootDSE["supportedFeatures"]}

    def bind_gssapi(self):
        self.conn.sasl_interactive_bind_s("", ldap.sasl.gssapi())

    def whoami(self):
        return self.conn.whoami_s()

    def has_control(self, oid):
        return oid in self._controls

    def has_feature(self, oid):
        return oid in self._features

    def read_entry(self, dn, raw=False):
        attrs = self.conn.read_s(dn)
        if not raw:
            attrs = _decode_dict_values(attrs)
        attrs = CaseInsensitiveDict(attrs)
        return attrs

    def read_attr(self, dn, attr, raw=False):
        attrs = self.conn.read_s(dn, attrlist=[attr])
        if not raw:
            attrs = _decode_dict_values(attrs)
        attrs = CaseInsensitiveDict(attrs)
        return attrs[attr]

    def increment_attr(self, dn, attr, incr=1, use_increment=True):
        import random
        import time

        if use_increment and \
           self.has_control(OID_LDAP_CONTROL_POSTREAD) and \
           self.has_feature(OID_LDAP_FEATURE_MODIFY_INCREMENT):
            incr = str(incr).encode()
            ctrl = ldap.controls.readentry.PostReadControl(attrList=[attr])
            res = self.conn.modify_ext_s(dn,
                                         [(ldap.MOD_INCREMENT, attr, incr)],
                                         serverctrls=[ctrl])
            for outctrl in res[3]:
                if outctrl.controlType == ctrl.controlType:
                    values = CaseInsensitiveDict(outctrl.entry)[attr]
                    return int(values[0])

        wait = 0
        while True:
            old_val = self.read_attr(dn, attr, raw=True)[0]
            new_val = str(int(old_val) + incr).encode()
            try:
                self.conn.modify_s(dn,
                                   [(ldap.MOD_DELETE, attr, old_val),
                                    (ldap.MOD_ADD, attr, new_val)])
                done = True
            except ldap.NO_SUCH_ATTRIBUTE as e:
                Core.debug("swap (%r, %r) failed: %r", old_val, new_val, e)
                wait += 1
                time.sleep(0.05 * 2**random.randint(0, wait))
            else:
                break
        return int(new_val)
