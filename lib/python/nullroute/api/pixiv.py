import json
from nullroute.core import Core, Env
import nullroute.sec
import os
import pixivpy3
import requests
import time

class PixivClient():
    def __init__(self):
        self.api = pixivpy3.PixivAPI()
        self.ua = requests.Session()

        self.ua.mount("http://", requests.adapters.HTTPAdapter(max_retries=3))
        self.ua.mount("https://", requests.adapters.HTTPAdapter(max_retries=3))

    # OAuth token persistence

    def _load_token(self):
        path = Env.find_cache_file("pixiv.auth.json")
        try:
            with open(path, "r") as fh:
                data = json.load(fh)
            return data
        except FileNotFoundError:
            return None
        except Exception as e:
            Core.debug("could not load %r: %r", path, e)
            self._forget_token()
            return None

    def _store_token(self, token):
        path = Env.find_cache_file("pixiv.auth.json")
        data = {
            "access_token": token.response.access_token,
            "refresh_token": token.response.refresh_token,
            "expires_at": int(time.time() + token.response.expires_in),
            "user_id": token.response.user.id,
        }
        try:
            with open(path, "w") as fh:
                json.dump(data, fh)
            return True
        except Exception as e:
            Core.warn("could not write %r: %r", path, e)
            return False

    def _forget_token(self):
        path = Env.find_cache_file("pixiv.auth.json")
        os.unlink(path)

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
            if data.get("expires_at", -1) > time.time():
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
