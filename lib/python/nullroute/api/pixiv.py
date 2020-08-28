from functools import lru_cache
import json
from nullroute.core import Core, Env
import nullroute.sec
from nullroute.sec.util import OAuthTokenCache
import os
import pixivpy3
import requests
import time

class PixivApiError(Exception):
    pass

class PixivApiClient():
    def __init__(self):
        self.ua = requests.Session()
        self.ua.mount("http://", requests.adapters.BaseAdapter())
        self.ua.mount("https://", requests.adapters.HTTPAdapter(max_retries=3))

        self.tc = OAuthTokenCache("api.pixiv.net", display_name="Pixiv API")

        self.api = pixivpy3.PixivAPI()
        if not hasattr(self.api, "client_secret"):
            Core.warn("this pixivpy3.PixivAPI version does not allow overridding client_secret; OAuth won't work properly")
        self.api.client_id = "MOBrBDS8blbauoSck0ZfDbtuzpyT"
        self.api.client_secret = "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
        self.api.requests = self.ua

    def _load_token(self):
        return self.tc.load_token()

    def _store_token(self, token):
        data = {
            "access_token": token.response.access_token,
            "refresh_token": token.response.refresh_token,
            "expires_at": int(time.time() + token.response.expires_in),
            "user_id": token.response.user.id,
        }
        return self.tc.store_token(data)

    def _forget_token(self, token):
        return self.tc.forget_token()

    # API authentication

    def _load_creds(self):
        creds = nullroute.sec.get_netrc("pixiv.net", service="api")
        Core.trace("got credentials from netrc: %r", creds)
        return creds

    def _authenticate(self):
        if self.api.user_id:
            Core.warn("BUG: _authenticate() called twice")
            return True

        data = self._load_token()
        if data:
            Core.trace("loaded token: %r", data)
            exp = data.get("expires_at", 0)
            now = time.time()
            # Check whether it will still be valid during the entire script runtime,
            # hence the "+ 300". (In particular because the token lasts exactly 1 hour,
            # so it will expire every 4th cronjob run, *usually during the run.*)
            if os.environ.get("FORCE_TOKEN_REFRESH"):
                Core.debug("access token invalidated by environment variable, renewing")
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
            else:
                try:
                    token = self.api.auth(refresh_token=data["refresh_token"])
                    Core.debug("refreshed access token: %r", token)
                except Exception as e:
                    Core.err("could not refresh access token: %r", e)
                    #self._forget_token()
                else:
                    self._store_token(token)
                    return True

        data = self._load_creds()
        if data:
            Core.info("logging in to Pixiv as %r", data["login"])
            try:
                token = self.api.auth(username=data["login"],
                                      password=data["password"])
            except Exception as e:
                Core.warn("could not log in using username & password: %r", e)
            else:
                self._store_token(token)
                return True

        Core.die("could not log in to Pixiv (no credentials)")
        return False

    def _check_token_error(self, resp):
        try:
            if resp["errors"]["system"]["message"] == "The access token provided is invalid.":
                data = self._load_token()
                Core.notice("currently had token: %r", data)
                valid_for = data["expires_at"] - time.time()
                if valid_for > 0:
                    Core.notice("should be valid for %d more seconds", valid_for)
                else:
                    Core.notice("already expired %d seconds ago", -valid_for)
        except KeyError:
            pass

    ## JSON API functions

    @lru_cache(maxsize=1024)
    def get_illust_info(self, illust_id):
        Core.trace("calling api.works(illust_id=%r)", illust_id)
        resp = self.api.works(illust_id)
        if resp["status"] == "success":
            return resp["response"][0]
        else:
            self._check_token_error(resp)
            raise PixivApiError("API call failed: %r" % resp)

    @lru_cache(maxsize=1024)
    def get_member_info(self, member_id):
        Core.trace("calling api.users(member_id=%r)", member_id)
        resp = self.api.users(member_id)
        if resp["status"] == "success":
            return resp["response"][0]
        else:
            self._check_token_error(resp)
            raise PixivApiError("API call failed: %r" % resp)

    def get_member_works(self, member_id, **kwargs):
        resp = self.api.users_works(member_id, **kwargs)
        if resp["status"] == "success":
            # paginated API -- include {pagination:, count:}
            return resp
        else:
            self._check_token_error(resp)
            raise PixivApiError("API call failed: %r" % resp)

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
