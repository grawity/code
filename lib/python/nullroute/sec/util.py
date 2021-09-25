import json
from nullroute.core import Core
import nullroute.sec

class TokenCache(object):
    TOKEN_SCHEMA = "org.eu.nullroute.BearerToken"
    TOKEN_PROTO = "cookie"
    TOKEN_NAME = "Auth token for %s"

    def __init__(self, domain, display_name=None, user_name=None):
        self.domain = domain
        self.display_name = display_name or domain
        self.user_name = user_name
        self.match_fields = {"xdg:schema": self.TOKEN_SCHEMA,
                             "protocol": self.TOKEN_PROTO,
                             "domain": self.domain}
        if self.user_name:
            self.match_fields = {**self.match_fields,
                                 "username": self.user_name}

    def load_token(self):
        Core.debug("loading auth token for %r", self.domain)
        try:
            Core.trace("trying to load token from libsecret: %r", self.match_fields)
            data = nullroute.sec.get_libsecret(self.match_fields)
            Core.trace("loaded token: %r", data)
            return json.loads(data)
        except KeyError:
            Core.debug("not found in libsecret")
            return None

    def store_token(self, data):
        Core.debug("storing auth token for %r", self.domain)
        try:
            nullroute.sec.store_libsecret(self.TOKEN_NAME % self.display_name,
                                          json.dumps(data),
                                          self.match_fields)
        except Exception as e:
            Core.debug("could not access libsecret: %r", e)

    def forget_token(self):
        Core.debug("flushing auth tokens for %r", self.domain)
        nullroute.sec.clear_libsecret(self.match_fields)

class OAuthTokenCache(TokenCache):
    TOKEN_SCHEMA = "org.eu.nullroute.OAuthToken"
    TOKEN_PROTO = "oauth"
    TOKEN_NAME = "OAuth token for %s"
