from functools import lru_cache
import json
from nullroute.core import Core, Env
from nullroute.scrape import Scraper
from nullroute.string import ObjectDict
import nullroute.sec
from nullroute.sec.util import TokenCache
import os
import requests
import time

def parse_query_string(query):
    return {k: requests.utils.unquote(v)
            for (k, v) in [x.split("=", 1)
                           for x in query.split("&")]}

def serialize_cookie(cookie):
    return {a: getattr(cookie, a)
            for a in ["version", "name", "value", "port", "domain", "path",
                      "secure", "expires", "rfc2109"]}

class PixivWebClient(Scraper):
    def __init__(self):
        super().__init__()

        self.tc = TokenCache("www.pixiv.net", display_name="Pixiv website")
        self.user_id = None

    def _load_token(self):
        return self.tc.load_token()

    def _store_token(self, token):
        return self.tc.store_token(token)

    def _load_creds(self):
        creds = nullroute.sec.get_netrc("pixiv.net", service="http")
        return creds

    def _validate(self):
        Core.debug("verifying session status")
        resp = self.get("https://www.pixiv.net/member.php", allow_redirects=False)
        if resp.is_redirect:
            Core.trace("member.php redirects to %r", resp.next.url)
            url = requests.utils.urlparse(resp.next.url)
            if url.path == "/member.php":
                query = parse_query_string(url.query)
                self.user_id = int(query["id"])
                Core.debug("session is valid, userid %r", self.user_id)
                return True
        Core.debug("session is not valid")
        return False

    def _authenticate(self):
        if self.user_id:
            return True

        psid = os.environ.get("PIXIV_PHPSESSID")
        if psid:
            cookie = requests.cookies.create_cookie(name="PHPSESSID",
                                                    value=psid,
                                                    domain=".pixiv.net")
            cookie.expires = int(time.time() + 3600)
            Core.debug("storing cookie: %r", cookie)
            self._store_token(serialize_cookie(cookie))

        token = self._load_token()
        if token:
            if os.environ.get("FORCE_TOKEN_REFRESH"):
                del os.environ["FORCE_TOKEN_REFRESH"]
                token_valid = False
            else:
                #token_valid = token["expires"] >= time.time()
                # Just pretend the cookie is still valid, as it now comes
                # from the web browser which will keep it active, and we
                # don't really have any way to get a new one anyway.
                token_valid = True
                token["expires"] = int(time.time() + 86400 * 30)

            if token_valid:
                cookie = requests.cookies.create_cookie(**token)
                Core.debug("loaded cookie: %r", cookie)
                self.ua.cookies.set_cookie(cookie)
                if self._validate():
                    cookie.expires = int(time.time() + 86400 * 30)
                    Core.debug("updating cookie: %r", cookie)
                    self._store_token(serialize_cookie(cookie))
                    return True
            else:
                Core.debug("cookie has expired")

        raise Exception("Pixiv cookie not found or expired")

    def _get_json(self, *args, **kwargs):
        resp = self.get(*args, **kwargs)
        resp.raise_for_status()
        data = json.loads(resp.text, object_hook=ObjectDict)
        Core.trace("JSON (%r) = %r", args, data)
        if data.get("error"):
            raise Exception("API error: %r", data.get("message") or data["error"])
        else:
            return data["body"]

    def _post_json(self, *args, **kwargs):
        resp = self.ua.post(*args, **kwargs)
        resp.raise_for_status()
        data = json.loads(resp.text, object_hook=ObjectDict)
        Core.trace("JSON (%r) = %r", args, data)
        if data.get("error"):
            raise Exception("API error: %r", data.get("message") or data["error"])
        else:
            return data["body"]

    @lru_cache(maxsize=1024)
    def get_user(self, user_id):
        self._authenticate()
        return self._get_json("https://www.pixiv.net/ajax/user/%s" % user_id)

    @lru_cache(maxsize=1024)
    def get_illust(self, illust_id):
        self._authenticate()
        return self._get_json("https://www.pixiv.net/ajax/illust/%s" % illust_id)

    @lru_cache(maxsize=1024)
    def get_fanbox_creator(self, user_id):
        self._authenticate()
        return self._get_json("https://www.pixiv.net/ajax/fanbox/creator",
                              params={"userId": post_id})

    @lru_cache(maxsize=1024)
    def get_fanbox_post(self, post_id):
        # returns partial information if unauthenticated
        self._authenticate()
        return self._get_json("https://fanbox.pixiv.net/api/post.info",
                              params={"postId": post_id},
                              headers={"origin": "https://www.pixiv.net"})
