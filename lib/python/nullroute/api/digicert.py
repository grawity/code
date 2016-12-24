import enum
from functools import lru_cache
from nullroute.core import *
import requests

class DevError(BaseException):
    pass

class Platform(enum.IntEnum):
    SSL_Other = -1
    SSL_Apache = 2
    SSL_Nginx = 45

class CertCentralClient(object):
    # https://www.digicert.com/services/v2/documentation
    base = "https://www.digicert.com/services/v2"

    def __init__(self, api_key=None):
        self.ua = requests.Session()
        if api_key:
            self.set_api_key(api_key)

    def set_api_key(self, api_key):
        self.ua.headers["X-DC-DEVKEY"] = api_key

    def get(self, ep, *args, **kwargs):
        uri = self.base + ep
        Core.debug("fetching %r" % uri)
        resp = self.ua.get(uri, *args, **kwargs)
        resp.raise_for_status()
        return resp

    def post(self, ep, *args, **kwargs):
        uri = self.base + ep
        Core.debug("posting to %r" % uri)
        resp = self.ua.post(uri, *args, **kwargs)
        resp.raise_for_status()
        return resp

    @lru_cache()
    def get_myself(self):
        resp = self.get("/user/me")
        return resp.json()

    def get_default_container(self):
        return self.get_myself()["container"]["id"]

    def get_container_authorizations(self, container_id):
        return self.get("/authorization",
                        params={"container_id": container_id})

    @lru_cache()
    def get_organizations(self):
        resp = self.get("/organization")
        data = resp.json()
        if data["page"]["total"] > 1:
            raise DevError("paging not yet implemented for %r" % data)
        return data["organizations"]

    def get_certificate(self, cert_id, format="p7b"):
        if format is None:
            resp = self.get("/certificate/%s/download/platform" % cert_id)
        else:
            resp = self.get("/certificate/%s/download/format/%s" % (cert_id, format))
        return resp.content

    def get_order(self, order_id):
        resp = self.get("/order/certificate/%s" % order_id)
        return resp.json()

    def post_order(self, order_type, order_data):
        resp = self.post("/order/certificate/%s" % order_type,
                         json=order_data)
        return resp.json()

    ### Convenience

    def request_tls_certificate(self, domains, csr, years=3):
        orgs = self.get_organizations()
        order = {
            "certificate": {
                "common_name": domains[0],
                "dns_names": domains,
                "csr": csr,
                "signature_hash": "sha256",
            },
            "organization": {
                "id": orgs[0]["id"],
            },
            "validity_years": years,
        }
        data = self.post_order("ssl_multi_domain", order)
        return data

    def get_order_certificate(self, order_id, format="p7b"):
        order = self.get_order(order_id)
        cert_id = order["certificate"]["id"]
        cert_type = order["product"]["type"]
        if cert_type == "ssl_certificate":
            cert_name = order["certificate"]["common_name"]
        else:
            raise DevError("don't know how to handle %r orders: %r" % (cert_type, order))
        data = self.get_certificate(cert_id, format)
        return {"cert": data, "name": cert_name, "type": cert_type}
