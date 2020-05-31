try:
    from .client_libldap import (LdapClient, quote_filter)
except ImportError:
    from .client_ldap3 import (LdapClient, quote_filter)

class NullrouteLdapClient(LdapClient):
    base = "dc=nullroute,dc=eu,dc=org"

    def __init__(self):
        super().__init__("ldaps://ldap.nullroute.eu.org")

def connect_auth():
    conn = NullrouteLdapClient()
    conn.bind_gssapi()
    return conn
