import ldap3
import ldap3.protocol.rfc4527
from ldap3.utils.ciDict import CaseInsensitiveDict
from nullroute.core import Core
import ssl

OID_LDAP_CONTROL_POSTREAD = "1.3.6.1.1.13.2"
OID_LDAP_FEATURE_MODIFY_INCREMENT = "1.3.6.1.1.14"

class LdapClient():
    def __init__(self, url, require_tls=True):
        Core.debug("creating ldap3 connection to %r", url)
        serv = ldap3.Server(url,
                            tls=ldap3.Tls(validate=ssl.CERT_REQUIRED),
                            get_info=ldap3.DSA)
        self.conn = ldap3.Connection(serv,
                                     #authentication=ldap3.SASL,
                                     #sasl_mechanism=ldap3.GSSAPI,
                                     raise_exceptions=True)
        self.conn.open()
        if require_tls and not url.startswith(("ldaps://", "ldapi://")):
            self.conn.start_tls()

        self._controls = {c[0] for c in self.conn.server.info.supported_controls}
        self._features = {c[0] for c in self.conn.server.info.supported_features}

    def bind_gssapi(self, authzid=""):
        self.conn.authentication = ldap3.SASL
        self.conn.sasl_mechanism = ldap3.GSSAPI
        self.conn.sasl_credentials = (self.conn.server.host, authzid)
        self.conn.bind()

    def whoami(self):
        return self.conn.extend.standard.who_am_i()

    def has_control(self, oid):
        return oid in self._controls

    def has_feature(self, oid):
        return oid in self._features

    def read_entry(self, dn, raw=False):
        if not self.conn.search(dn, "(objectClass=*)",
                                search_scope=ldap3.BASE,
                                attributes=[attr]):
            raise Exception("search failed", conn.result)
        entry = self.conn.entries[0]
        if raw:
            return CaseInsensitiveDict(entry.entry_raw_attributes)
        else:
            return CaseInsensitiveDict(entry.entry_attributes_as_dict)

    def read_attr(self, dn, attr, raw=False):
        if not self.conn.search(dn, "(objectClass=*)",
                                search_scope=ldap3.BASE,
                                attributes=[attr]):
            raise Exception("search failed", self.conn.result)
        entry = self.conn.entries[0]
        if raw:
            return entry[attr].raw_values
        else:
            return entry[attr].values

    def increment_attr(self, dn, attr, incr=1, use_increment=True):
        import random
        import time

        if use_increment and \
           self.has_control(OID_LDAP_CONTROL_POSTREAD) and \
           self.has_feature(OID_LDAP_FEATURE_MODIFY_INCREMENT):
            # this is far uglier than the Perl version already
            postread_ctrl = ldap3.protocol.rfc4527.post_read_control([attr])
            self.conn.modify(dn,
                             {attr: [(ldap3.MODIFY_INCREMENT, incr)]},
                             controls=[postread_ctrl])
            res = self.conn.result["controls"][OID_LDAP_CONTROL_POSTREAD]["value"]["result"]
            res = CaseInsensitiveDict(res)
            return res[attr][0]

        wait = 0
        while True:
            old_val = self.read_attr(dn, attr)[0]
            new_val = str(int(old_val) + incr)
            try:
                self.conn.modify(dn,
                                 {attr: [(ldap3.MODIFY_DELETE, old_val),
                                         (ldap3.MODIFY_ADD, new_val)]})
            except ldap3.core.exceptions.LDAPNoSuchAttributeResult as e:
                Core.debug("swap (%r, %r) failed: %r", old_val, new_val, e)
                wait += 1
                time.sleep(0.05 * 2**random.randint(0, wait))
            else:
                break
        return int(new_val)
