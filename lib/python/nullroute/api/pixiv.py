from functools import cache
import json
from nullroute.core import Core, Env
import nullroute.sec
from nullroute.sec.util import OAuthTokenCache
import os
import pixivpy3
import requests
import ssl
import time

class CustomAdapter(requests.adapters.HTTPAdapter):
    def init_poolmanager(self, *args, **kwargs):
        # When urllib3 hand-rolls a SSLContext, it sets 'options |= OP_NO_TICKET'
        # and CloudFlare really does not like this. We cannot control this behavior
        # in urllib3, but we *can* just pass our own standard context instead.
        ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        ctx.load_default_certs()
        ctx.set_alpn_protocols(["http/1.1"])
        return super().init_poolmanager(*args, **kwargs, ssl_context=ctx)

class PixivApiError(Exception):
    pass

class PixivApiClient():
    def __init__(self):
        self.ua = requests.Session()
        self.ua.mount("http://", requests.adapters.BaseAdapter())
        #self.ua.mount("https://", requests.adapters.HTTPAdapter(max_retries=10))
        self.ua.mount("https://", CustomAdapter(max_retries=10))
        #self.ua = cloudscraper.CloudScraper()
        #self.ua = cloudscraper.create_scraper()

        self.tc = OAuthTokenCache("api.pixiv.net", display_name="Pixiv API")

        self.api = pixivpy3.AppPixivAPI()
        self.api.requests = self.ua

    def _load_token(self):
        return self.tc.load_token()

    def _store_token(self, token):
        return self.tc.store_token(token)

    def _forget_token(self, token):
        return self.tc.forget_token()

    # API authentication

    def _authenticate(self):
        if self.api.user_id:
            return True

        refresh_token = None

        if data := self._load_token():
            Core.trace("loaded token: %r", data)
            refresh_token = data["refresh_token"]

            # Is the access token still valid?
            exp = data.get("expires_at", 0)
            now = time.time()
            # Check whether it will still be valid during the entire script runtime,
            # hence the "+ 300". (In particular because the token lasts exactly 1 hour,
            # so it will expire every 4th cronjob run, *usually during the run.*)
            if os.environ.get("FORCE_TOKEN_REFRESH"):
                Core.notice("access token invalidated by environment variable, renewing")
                token_valid = False
            elif exp >= (now + 300):
                Core.debug("access token still valid for %.1f seconds, using as-is", exp-now)
                token_valid = True
            elif exp >= now:
                Core.debug("access token is about to expire in %.1f seconds, renewing", exp-now)
                token_valid = False
            else:
                Core.debug("access token has expired %.1f seconds ago, renewing", now-exp)
                token_valid = False
            if token_valid:
                self.api.user_id = data["user_id"]
                self.api.access_token = data["access_token"]
                self.api.refresh_token = data["refresh_token"]
                return True

        if not refresh_token:
            creds = nullroute.sec.get_netrc("api.pixiv.net", service="oauth")
            if creds and creds["password"]:
                Core.debug("using refresh token from netrc: %r", creds)
                refresh_token = creds["password"]

        if not refresh_token:
            Core.die("could not log in to Pixiv -- no refresh token")
            return False

        try:
            token = self.api.auth(refresh_token=refresh_token)
            Core.debug("acquired access token: %r", token)
        except Exception as e:
            Core.die("could not acquire access token: %r", e)
            print(f"str(e) = {e}")
            print(f"e.args = {e.args!r}")
            #self._forget_token()
            return False
        else:
            data = {"access_token": token.response.access_token,
                    "refresh_token": token.response.refresh_token,
                    "expires_at": int(time.time() + token.response.expires_in),
                    "user_id": token.response.user.id}
            self._store_token(data)
            return True

    ## JSON API functions

    @cache
    def get_illust_info(self, illust_id):
        self._authenticate()
        Core.trace("calling api.illust_detail(illust_id=%r)", illust_id)
        resp = self.api.illust_detail(illust_id)
        if err := resp.get("error"):
            raise PixivApiError("API call failed: %r" % err)
        else:
            return resp["illust"]

    @cache
    def get_member_info(self, member_id):
        self._authenticate()
        Core.trace("calling api.user_detail(member_id=%r)", member_id)
        resp = self.api.user_detail(member_id)
        if err := resp.get("error"):
            raise PixivApiError("API call failed: %r" % err)
        else:
            # deliberately discard resp["profile"], etc.
            return resp["user"]

    @cache
    def get_illust_ugoira_info(self, illust_id):
        self._authenticate()
        Core.trace("calling api.ugoira_metadata(illust_id=%r)", illust_id)
        resp = self.api.ugoira_metadata(illust_id)
        if err := resp.get("error"):
            raise PixivApiError("API call failed: %r" % err)
        else:
            return resp["ugoira_metadata"]

import re

class PixivClient():
    MEMBER_FMT = "https://www.pixiv.net/member.php?id=%s"
    ILLUST_URL = "https://www.pixiv.net/member_illust.php?mode=%s&illust_id=%s"

    def __init__(self):
        self.member_name_map = {}
        self._load_member_name_map()

    def _load_member_name_map(self):
        map_path = Env.find_config_file("pixiv_member_names.txt")
        try:
            Core.debug("loading member aliases from %r", map_path)
            with open(map_path, "r") as fh:
                self.member_name_map = {}
                for line in fh:
                    if line.startswith((";", "#", "\n")):
                        continue
                    k, v = line.split("=")
                    self.member_name_map[k.strip()] = v.strip()
        except FileNotFoundError:
            Core.debug("member alias file %r not found; ignoring", map_path)

    def fmt_member_tag(self, member_id, member_name):
        member_name = self.member_name_map.get(str(member_id), member_name)
        if False:
            # Dropbox cannot sync non-BMP characters
            member_name = re.sub(r"[^\u0000-\uFFFF]",
                                 lambda m: "[U+%04X]" % ord(m.group(0)),
                                 member_name)
        if str(member_id) not in self.member_name_map:
            # Strip temporary info unless it was hardcoded in the map
            member_name = re.sub("(@|＠).*", "", member_name)
            member_name = re.sub(r"[◆✦|_✳︎]?([0-9一三]|月曜)日.+?[0-9]+[a-z]*", "",
                                 member_name)
        member_name = member_name.replace(" ", "_")
        return "%s_pixiv%s" % (member_name, member_id)

    def fmt_member_url(self, member_id):
        return self.MEMBER_FMT % (member_id,)

    def fmt_illust_url(self, illust_id, mode="medium"):
        return self.ILLUST_URL % (mode, illust_id)
