from functools import lru_cache
from nullroute.core import Core, Env
from nullroute.api.base import PersistentAuthBase
import nullroute.sec
import os
import pixivpy3
import requests
import time

class PixivApiError(Exception):
    pass

class PixivApiClient(PersistentAuthBase):
    TOKEN_SCHEMA = "org.eu.nullroute.OAuthToken"
    TOKEN_NAME = "Pixiv OAuth token"
    TOKEN_DOMAIN = "pixiv.net"
    TOKEN_PATH = Env.find_cache_file("pixiv.auth.json")

    def __init__(self):
        self.ua = requests.Session()
        self.ua.mount("http://", requests.adapters.HTTPAdapter(max_retries=3))
        self.ua.mount("https://", requests.adapters.HTTPAdapter(max_retries=3))

        self.api = pixivpy3.PixivAPI()
        if not hasattr(self.api, "client_secret"):
            Core.warn("this pixivpy3.PixivAPI version does not allow overridding client_secret; OAuth won't work properly")
        self.api.client_id = "MOBrBDS8blbauoSck0ZfDbtuzpyT"
        self.api.client_secret = "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
        self.api.requests = self.ua

    def _store_token(self, token):
        data = {
            "access_token": token.response.access_token,
            "refresh_token": token.response.refresh_token,
            "expires_at": int(time.time() + token.response.expires_in),
            "user_id": token.response.user.id,
        }
        extra = {
           "userid": token.response.user.id,
           "username": token.response.user.account,
        }
        return super()._store_token(data, extra)

    # API authentication

    def _load_creds(self):
        creds = nullroute.sec.get_netrc_service("pixiv.net", "api")
        return creds

    def _authenticate(self):
        if self.api.user_id:
            Core.warn("BUG: _authenticate() called twice")
            return True

        data = self._load_token()
        if data:
            if os.environ.get("FORCE_TOKEN_REFRESH"):
                token_valid = False
            else:
                token_valid = data["expires_at"] > time.time()

            if token_valid:
                Core.debug("access token within expiry time, using as-is")
                self.api.user_id = data["user_id"]
                self.api.access_token = data["access_token"]
                self.api.refresh_token = data["refresh_token"]
                return True
            else:
                Core.debug("access token has expired, renewing")
                try:
                    token = self.api.auth(refresh_token=data["refresh_token"])
                except Exception as e:
                    Core.warn("could not refresh access token: %r", e)
                    self._forget_token()
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

    ## JSON API functions

    @lru_cache(maxsize=1024)
    def get_illust_info(self, illust_id):
        resp = self.api.works(illust_id)
        if resp["status"] == "success":
            return resp["response"][0]
        else:
            raise PixivApiError("API call failed: %r" % resp)

    @lru_cache(maxsize=1024)
    def get_member_info(self, member_id):
        resp = self.api.users(member_id)
        if resp["status"] == "success":
            return resp["response"][0]
        else:
            raise PixivApiError("API call failed: %r" % resp)

    def get_member_works(self, member_id, **kwargs):
        resp = self.api.users_works(member_id, **kwargs)
        if resp["status"] == "success":
            # paginated API -- include {pagination:, count:}
            return resp
        else:
            raise PixivApiError("API call failed: %r" % resp)

class PixivClient():
    MEMBER_FMT = "https://www.pixiv.net/member.php?id=%s"
    ILLUST_URL = "https://www.pixiv.net/member_illust.php?mode=%s&illust_id=%s"

    def __init__(self):
        self._load_member_name_map()

    def _load_member_name_map(self):
        self.member_name_map = {}
        try:
            _map_path = Env.find_config_file("pixiv_member_names.txt")
            Core.debug("loading member aliases from %r", _map_path)
            with open(_map_path, "r") as fh:
                for line in fh:
                    if line.startswith(";"):
                        continue
                    k, v = line.split("=")
                    k = int(k.strip())
                    v = v.strip()
                    self.member_name_map[k] = v
        except FileNotFoundError:
            pass

    def fmt_member_tag(self, member_id, member_name):
        member_name = self.member_name_map.get(member_id, member_name)
        member_name = re.sub("(@|＠).*", "", member_name)
        member_name = re.sub(r"[◆|_]?[0-9一三]日.+?[0-9]+[a-z]*", "", member_name)
        member_name = member_name.replace(" ", "_")
        return "%s_pixiv%s" % (member_name, member_id)

    def fmt_member_url(self, member_id):
        return self.MEMBER_FMT % (member_id,)

    def fmt_illust_url(self, illust_id, mode="medium"):
        return self.ILLUST_URL % (mode, illust_id)
