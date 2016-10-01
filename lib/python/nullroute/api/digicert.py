from nullroute.core import *
from pprint import pprint
import requests
from requests.exceptions import HTTPError

class CertCentralClient(object):
    # https://www.digicert.com/services/v2/documentation/authorization/authorization-list
    base = "https://www.digicert.com/services/v2"

    def __init__(self, account_id=None, api_key=None):
        self.account_id = account_id
        self.api_key = api_key

        self.ua = requests.Session()
        if api_key:
            self.ua.headers["X-DC-DEVKEY"] = api_key

        self._user = None

    def get(self, ep, params=None, *args, **kwargs):
        kwargs.setdefault("params", params)

        uri = self.base + ep
        Core.debug("fetching %r" % uri)

        r = self.ua.get(uri, *args, **kwargs)
        r.raise_for_status()
        return r

    def _api_get_myself(self):
        return self.get("/user/me")

    def _api_get_ctr_authorizations(self, container_id):
        return self.get("/authorization",
                        params={"container_id": container_id})

    def _api_get_order(self, order_id):
        return self.get("/order/certificate/%s" % order_id)

    def _api_get_certificate(self, cert_id, format="p7b"):
        return self.get("/certificate/%s/download/format/%s" % (cert_id, format))

    def get_myself(self):
        if not self._user:
            self._user = self._api_get_myself().json()
        return self._user

    def get_default_container(self):
        return self.get_myself()["container"]["id"]

    def get_order(self, order_id):
        return self._api_get_order(order_id).json()

    def get_order_certificate(self, order_id):
        order = self.get_order(order_id)
        cert_id = order["certificate"]["id"]

        if order["product"]["type"] == "ssl_certificate":
            cert_name = order["certificate"]["common_name"]
            cert_names = order["certificate"]["dns_names"]
        elif order["product"]["type"] == "client_certificate":
            pass

        cert_data = self._api_get_certificate(cert_id, format="p7b")
        raw_pkcs7 = cert_data.content

        return cert_name, raw_pkcs7
