import json
from nullroute.core import Core, Env
import nullroute.sec
import os

def try_load_keyring(domain, **kwargs):
    schema = "org.eu.nullroute.OAuthToken"
    attrs = {"xdg:schema": schema, "domain": domain, **kwargs}
    data = None
    try:
        data = nullroute.sec.get_libsecret(attrs)
        try:
            data = json.loads(data)
        except json.decoder.JSONDecodeError:
            nullroute.sec.clear_libsecret(attrs)
    except KeyError:
        pass
    return data

def store_keyring(name, data, domain, **kwargs):
    schema = "org.eu.nullroute.OAuthToken"
    attrs = {"xdg:schema": schema, "domain": domain, **kwargs}
    data = json.dumps(data)
    return nullroute.sec.store_libsecret(name, data, attrs)

def clear_keyring(domain, **kwargs):
    schema = "org.eu.nullroute.OAuthToken"
    attrs = {"xdg:schema": schema, "domain": domain, **kwargs}
    return nullroute.sec.clear_libsecret(attrs)

class TokenCache(object):
    TOKEN_SCHEMA = "org.eu.nullroute.BearerToken"
    TOKEN_NAME = "Auth token for %s"

    def __init__(self, domain, display_name=None):
        self.domain = domain
        self.display_name = display_name or domain
        self.token_path = Env.find_cache_file("token_%s.json" % domain)

    def _store_token_libsecret(self, data):
        nullroute.sec.store_libsecret(self.TOKEN_NAME % self.display_name,
                                      json.dumps(data),
                                      {"xdg:schema": self.TOKEN_SCHEMA,
                                       "domain": self.domain})

    def _load_token_libsecret(self):
        data = nullroute.sec.get_libsecret({"xdg:schema": self.TOKEN_SCHEMA,
                                            "domain": self.domain})
        return json.loads(data)

    def _clear_token_libsecret(self):
        nullroute.sec.clear_libsecret({"xdg:schema": self.TOKEN_SCHEMA,
                                       "domain": self.domain})

    def _store_token_file(self, data):
        with open(self.token_path, "w") as fh:
            json.dump(data, fh)

    def _load_token_file(self):
        with open(self.token_path, "r") as fh:
            data = fh.read()
        return json.loads(data)

    def _clear_token_file(self):
        try:
            os.unlink(self.token_path)
        except FileNotFoundError:
            pass

    def load_token(self):
        Core.debug("loading auth token for %r", self.domain)
        try:
            return self._load_token_libsecret()
        except KeyError:
            try:
                return self._load_token_file()
            except FileNotFoundError:
                pass
            except Exception as e:
                Core.debug("could not load %r: %r", self.token_path, e)
                self.forget_token()
        return None

    def store_token(self, data):
        Core.debug("storing auth token for %r", self.domain)
        self._store_token_libsecret(data)
        try:
            self._store_token_file(data)
        except Exception as e:
            Core.warn("could not write %r: %r", self.token_path, e)

    def forget_token(self):
        Core.debug("flushing auth tokens for %r", self.domain)
        self._clear_token_libsecret()
        self._clear_token_file()

class OAuthTokenCache(TokenCache):
    TOKEN_SCHEMA = "org.eu.nullroute.OAuthToken"
    TOKEN_NAME = "OAuth token for %s"
