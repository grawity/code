import json
from nullroute.core import Core, Env
import nullroute.sec
import os
import pixivpy3
import requests
import time

class PixivClient():
    TOKEN_SCHEMA = "org.eu.nullroute.OAuthToken"
    TOKEN_PATH = Env.find_cache_file("pixiv.auth.json")

    def __init__(self):
        self.api = pixivpy3.PixivAPI()
        self.ua = requests.Session()

        self.ua.mount("http://", requests.adapters.HTTPAdapter(max_retries=3))
        self.ua.mount("https://", requests.adapters.HTTPAdapter(max_retries=3))

    # OAuth token persistence

    def _load_token(self):
        try:
            data = nullroute.sec.get_libsecret({"xdg:schema": self.TOKEN_SCHEMA,
                                                "domain": "pixiv.net"})
            Core.debug("found OAuth token in keyring")
            return json.loads(data)
        except KeyError:
            try:
                with open(self.TOKEN_PATH, "r") as fh:
                    data = json.load(fh)
                Core.debug("found OAuth token in filesystem")
                return data
            except FileNotFoundError:
                pass
            except Exception as e:
                Core.debug("could not load %r: %r", self.TOKEN_PATH, e)
                self._forget_token()
        return None

    def _store_token(self, token):
        data = {
            "access_token": token.response.access_token,
            "refresh_token": token.response.refresh_token,
            "expires_at": int(time.time() + token.response.expires_in),
            "user_id": token.response.user.id,
        }
        Core.debug("storing OAuth tokens")
        nullroute.sec.store_libsecret("Pixiv OAuth token",
                                      json.dumps(data),
                                      {"xdg:schema": self.TOKEN_SCHEMA,
                                       "domain": "pixiv.net",
                                       "userid": token.response.user.id,
                                       "username": token.response.user.account})
        try:
            with open(self.TOKEN_PATH, "w") as fh:
                json.dump(data, fh)
            return True
        except Exception as e:
            Core.warn("could not write %r: %r", self.TOKEN_PATH, e)
            return False

    def _forget_token(self):
        Core.debug("flushing OAuth tokens")
        nullroute.sec.clear_libsecret({"xdg:schema": self.TOKEN_SCHEMA,
                                       "domain": "pixiv.net"})
        os.unlink(self.TOKEN_PATH)

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
