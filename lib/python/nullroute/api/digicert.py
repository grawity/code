import enum
from functools import lru_cache
from nullroute.core import Core
from pprint import pprint
import requests

CERT_FORMATS = {
    "p7b":          ("p7b", "application/x-pkcs7-certificates"),
    "cer":          ("p7b", "application/x-pkcs7-certificates"),
    "pem_all":      ("pem", "TODO"),
    "pem_noroot":   ("pem", "TODO"),
    "default_cer":  ("zip", "application/zip"),
    "default_pem":  ("zip", "application/zip"),
    "default":      ("zip", "application/zip"),
    "apache":       ("zip", "application/zip"),
}

class DevError(BaseException):
    pass

class StillProcessingError(BaseException):
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

    def get_certificate(self, cert_id, format="p7b", headers=False):
        if format:
            resp = self.get("/certificate/%s/download/format/%s" % (cert_id, format))
        else:
            resp = self.get("/certificate/%s/download/platform" % cert_id)
        return resp if headers else resp.content

    def get_order(self, order_id):
        resp = self.get("/order/certificate/%s" % order_id)
        return resp.json()

    def post_order(self, order_type, order_data):
        resp = self.post("/order/certificate/%s" % order_type,
                         json=order_data)
        return resp.json()

    ### Convenience

    def request_tls_certificate(self, domains, csr, years=3):
        Core.debug("posting a ssl_multi_domain order for %r", domains)
        org = self.get_organizations()[0]
        order = {
            "certificate": {
                "common_name": domains[0],
                "csr": csr,
                "dns_names": domains,
                "signature_hash": "sha256",
            },
            "organization": { "id": org["id"] },
            "validity_years": years,
        }
        data = self.post_order("ssl_multi_domain", order)
        return data

    def get_order_certificate(self, order_id, format=None):
        order = self.get_order(order_id)
        if order["status"] in {"pending", "processing"}:
            raise StillProcessingError(order)
        elif order["status"] != "issued":
            pprint(order)
            raise DevError("unknown order status %r" % order["status"])
        cert_id = order["certificate"]["id"]
        cert_type = order["product"]["type"]
        try:
            serial = order["certificate"]["serial_number"]
        except KeyError as e:
            pprint(order)
            raise
        if cert_type == "ssl_certificate":
            format = format or "pem_noroot"
            cert_name = order["certificate"]["common_name"]
        elif cert_type == "client_certificate":
            format = format or "p7b"
            cert_name = order["certificate"]["emails"][0]
        else:
            raise DevError("don't know how to handle %r orders: %r" % (cert_type, order))
        resp = self.get_certificate(cert_id, format, headers=True)
        return {"cert": resp.content,
                "type": resp.headers["Content-Type"],
                "name": cert_name,
                "format": format,
                "serial": serial}
