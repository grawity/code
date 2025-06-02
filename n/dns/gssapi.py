import dns.rdtypes.ANY.TKEY
import dns.resolver
import dns.update
import gssapi
import socket
import time
import uuid

def _build_tkey_query(token, key_ring, key_name):
    inception_time = int(time.time())
    tkey = dns.rdtypes.ANY.TKEY.TKEY(dns.rdataclass.ANY,
                                     dns.rdatatype.TKEY,
                                     dns.tsig.GSS_TSIG,
                                     inception_time,
                                     inception_time,
                                     3,
                                     dns.rcode.NOERROR,
                                     token,
                                     b"")

    query = dns.message.make_query(key_name,
                                   dns.rdatatype.TKEY,
                                   dns.rdataclass.ANY)
    query.keyring = key_ring
    query.find_rrset(dns.message.ADDITIONAL,
                     key_name,
                     dns.rdataclass.ANY,
                     dns.rdatatype.TKEY,
                     create=True).add(tkey)
    return query

def _probe_server(server_name, zone):
    gai = socket.getaddrinfo(str(server_name),
                             "domain",
                             socket.AF_UNSPEC,
                             socket.SOCK_DGRAM)
    for af, sf, pt, cname, sa in gai:
        query = dns.message.make_query(zone, "SOA")
        res = dns.query.udp(query, sa[0], timeout=2)
        return sa[0]

def gss_tsig_negotiate(server_name, server_addr, creds=None):
    # Acquire GSSAPI credentials
    gss_name = gssapi.Name(f"DNS@{server_name}",
                           gssapi.NameType.hostbased_service)
    gss_ctx = gssapi.SecurityContext(name=gss_name,
                                     creds=creds,
                                     usage="initiate")

    # Name generation tips: https://tools.ietf.org/html/rfc2930#section-2.1
    key_name = dns.name.from_text(f"{uuid.uuid4()}.{server_name}")
    tsig_key = dns.tsig.Key(key_name, gss_ctx, dns.tsig.GSS_TSIG)

    key_ring = {key_name: tsig_key}
    key_ring = dns.tsig.GSSTSigAdapter(key_ring)

    in_token = None
    while not gss_ctx.complete:
        out_token = gss_ctx.step(in_token)
        if not out_token:
            break
        tkey_query = _build_tkey_query(out_token, key_ring, key_name)
        response = dns.query.tcp(tkey_query, server_addr, timeout=5)
        in_token = response.answer[0][0].key

    return key_ring, key_name

def master_for_zone(zone):
    ans = dns.resolver.resolve(zone, "SOA")
    return ans.rrset[0].mname.canonicalize()

def gss_tsig_update(zone, update_msg,
                    server_name=None,
                    server_addr=None,
                    gss_credentials=None):
    if not server_name:
        server_name = master_for_zone(zone)
    if not server_addr:
        server_addr = _probe_server(server_name, zone)

    key_ring, key_name = gss_tsig_negotiate(server_name,
                                            server_addr,
                                            gss_credentials)

    update_msg.use_tsig(keyring=key_ring,
                        keyname=key_name,
                        algorithm=dns.tsig.GSS_TSIG)
    response = dns.query.tcp(update_msg, server_addr)
    return response

def gss_tsig_axfr(zone,
                  server_name=None,
                  server_addr=None,
                  gss_credentials=None):
    if not server_name:
        server_name = master_for_zone(zone)
    if not server_addr:
        server_addr = _probe_server(server_name, zone)

    key_ring, key_name = gss_tsig_negotiate(server_name,
                                            server_addr,
                                            gss_credentials)

    response = dns.query.xfr(server_addr, zone,
                             keyring=key_ring,
                             keyname=key_name)
    zone = dns.zone.from_xfr(response)
    return zone
