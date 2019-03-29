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

class PixivWebClient(Scraper):
    def __init__(self):
        super().__init__()

        self.tc = TokenCache("www.pixiv.net", display_name="Pixiv website")
        self.user_id = None

    def _load_token(self):
        #return self.tc.load_token()

        # TODO: delete after 2019-05-01
        data = self.tc.load_token()
        if not data:
            old_path = Env.find_cache_file("pixiv_web.auth.json")
            if os.path.exists(old_path):
                Core.notice("migrating auth token from %r", old_path)
                with open(old_path, "r") as fh:
                    data = json.load(fh)
                self.tc.store_token(data)
                os.unlink(old_path)
        return data

    def _store_token(self, token):
        return self.tc.store_token(token)

    def _load_creds(self):
        creds = nullroute.sec.get_netrc_service("pixiv.net", "http")
        return creds

    def _authenticate(self):
        if self.user_id:
            return True

        token = self._load_token()
        if token:
            if os.environ.get("FORCE_TOKEN_REFRESH"):
                token_valid = False
            else:
                token_valid = token["expires"] >= time.time()

            if token_valid:
                cookie = requests.cookies.create_cookie(**token)
                Core.debug("loaded cookie: %r", cookie)
                self.ua.cookies.set_cookie(cookie)
                Core.debug("verifying session status")
                resp = self.get("https://www.pixiv.net/member.php", allow_redirects=False)
                if resp.is_redirect:
                    url = requests.utils.urlparse(resp.next.url)
                    if url.path == "/member.php":
                        query = parse_query_string(url.query)
                        self.user_id = int(query["id"])
                        Core.debug("session is valid, userid %r", self.user_id)
                        return True
                    else:
                        raise Exception("authentication failed")
                else:
                    raise Exception("authentication POST request failed")
            else:
                Core.debug("cookie has expired")

        creds = self._load_creds()
        if creds:
            Core.info("logging in to Pixiv as %r", creds["login"])
            page = self.get_page("https://accounts.pixiv.net/login?lang=en")
            key = page.select_one("input[name='post_key']")["value"]

            page = self.ua.post("https://accounts.pixiv.net/api/login?lang=en",
                                data={"post_key": key,
                                      "pixiv_id": creds["login"],
                                      "password": creds["password"]})
            print(page)

            cookie = self.ua.cookies._cookies[".pixiv.net"]["/"]["PHPSESSID"]
            token = {a: getattr(cookie, a)
                     for a in ["version", "name", "value", "port", "domain", "path",
                               "secure", "expires", "rfc2109"]}
            Core.debug("token = %r", token)
            self._store_token(token)
            return True
        else:
            raise Exception("Pixiv credentials not found")

    def _get_json(self, *args, **kwargs):
        self._authenticate()
        resp = self.get(*args, **kwargs)
        resp.raise_for_status()
        data = json.loads(resp.text, object_hook=ObjectDict)
        if data["error"]:
            raise Exception("API error: %r", data["message"])
        else:
            return data["body"]

    @lru_cache(maxsize=1024)
    def get_user(self, user_id):
        return self._get_json("https://www.pixiv.net/ajax/user/%s" % user_id)

    @lru_cache(maxsize=1024)
    def get_illust(self, illust_id):
        return self._get_json("https://www.pixiv.net/ajax/illust/%s" % illust_id)

    @lru_cache(maxsize=1024)
    def get_fanbox_creator(self, user_id):
        return self._get_json("https://www.pixiv.net/ajax/fanbox/creator",
                              params={"userId": post_id})

    @lru_cache(maxsize=1024)
    def get_fanbox_post(self, post_id):
        return self._get_json("https://www.pixiv.net/ajax/fanbox/post",
                              params={"postId": post_id})
