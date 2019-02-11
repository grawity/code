try:
    from .client_libldap import LdapClient
except ImportError:
    from .client_ldap3 import LdapClient

class NullrouteLdapClient(LdapClient):
    root = "dc=nullroute,dc=eu,dc=org"

    def __init__(self):
        super().__init__("ldaps://ldap.nullroute.eu.org")
