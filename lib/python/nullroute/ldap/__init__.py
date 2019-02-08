try:
    from .client_libldap import LdapClient
except ImportError:
    from .client_ldap3 import LdapClient
