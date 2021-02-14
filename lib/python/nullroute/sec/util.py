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
    TOKEN_PROTO = "cookie"
    TOKEN_NAME = "Auth token for %s"

    def __init__(self, domain, display_name=None, user_name=None):
        self.domain = domain
        self.display_name = display_name or domain
        self.user_name = user_name
        self.token_path = Env.find_cache_file("token_%s.json" % domain)
        self.match_fields = {"xdg:schema": self.TOKEN_SCHEMA,
                              "domain": self.domain}
        if self.user_name:
            self.match_fields = {**self.match_fields,
                                 "username": self.user_name}

    def _store_token_libsecret(self, data):
        nullroute.sec.store_libsecret(self.TOKEN_NAME % self.display_name,
                                      json.dumps(data),
                                      {**self.match_fields,
                                       "protocol": self.TOKEN_PROTO})

    def _load_token_libsecret(self):
        if self.user_name:
            try:
                Core.trace("trying to load token from libsecret: %r", self.match_fields)
                data = nullroute.sec.get_libsecret(self.match_fields)
                Core.trace("loaded token: %r", data)
                return json.loads(data)
            except KeyError:
                Core.debug("entry not found; retrying without username")
                old_match_fields = {**self.match_fields}
                del old_match_fields["username"]
                data = nullroute.sec.get_libsecret(old_match_fields)
                Core.debug("migrating entry to add username field")
                nullroute.sec.clear_libsecret(old_match_fields)
                self._store_token_libsecret(json.loads(data))
                return json.loads(data)
        else:
            Core.trace("trying to load token from libsecret: %r", self.match_fields)
            data = nullroute.sec.get_libsecret(self.match_fields)
            Core.trace("loaded token: %r", data)
            return json.loads(data)

    def _clear_token_libsecret(self):
        nullroute.sec.clear_libsecret(self.match_fields)

    def _store_token_file(self, data):
        with open(self.token_path, "w") as fh:
            os.chmod(fh.fileno(), 0o600)
            json.dump(data, fh)

    def _load_token_file(self):
        Core.trace("trying to load token from file: %r", self.token_path)
        with open(self.token_path, "r") as fh:
            data = fh.read()
        Core.trace("loaded token: %r", data)
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
            Core.debug("not found in libsecret; trying filesystem")
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
        try:
            self._store_token_libsecret(data)
        except Exception as e:
            Core.debug("could not access libsecret: %r", e)
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
    TOKEN_PROTO = "oauth"
    TOKEN_NAME = "OAuth token for %s"
