import ldap3
import ssl

def connect_gssapi(host):
    serv = ldap3.Server(host,
                        tls=ldap3.Tls(validate=ssl.CERT_REQUIRED),
                        get_info=ldap3.GET_ALL_INFO)
    conn = ldap3.Connection(serv,
                            authentication=ldap3.AUTH_SASL,
                            sasl_mechanism=ldap3.GSSAPI)
    conn.open()
    if not conn.start_tls():
        raise Exception("start_tls failed", conn.result)
    if not conn.bind():
        raise Exception("bind failed", conn.result)
    return conn
