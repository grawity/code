import json
from nullroute.core import Core
import time
import urllib.parse
import urllib.request

class OAuth2Client():
    def __init__(self, client_id,
                       client_secret=None,
                       authorization_url=None,
                       token_grant_url=None):
        self.client_id = client_id
        self.client_secret = client_secret
        self.authorization_url = authorization_url
        self.token_grant_url = token_grant_url
        self.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"

    def make_authorization_url(self, scope):
        params = {"client_id": self.client_id,
                  "response_type": "code",
                  "redirect_uri": self.redirect_uri,
                  "scope": scope}
        # # See OAUTH 5.1 for a definition of which characters need to be escaped
        params = urllib.parse.urlencode(params,
                                        quote_via=urllib.parse.quote,
                                        safe="~-._")
        return "%s?%s" % (self.authorization_url, params)

    def _grant_token(self, params):
        Core.debug("token grant URL: %r", self.token_grant_url)
        post_data = {"client_id": self.client_id,
                     "client_secret": self.client_secret,
                     **params}
        Core.debug("request data: %r", post_data)
        post_data = urllib.parse.urlencode(post_data).encode()
        Core.debug("encoded data: %r", post_data)
        response = urllib.request.urlopen(self.token_grant_url, post_data).read()
        response = json.loads(response)
        return {"expires_at": int(time.time() + response["expires_in"]),
                **response}

    def grant_token_via_authorization(self, authorization_code):
        return self._grant_token({"grant_type": "authorization_code",
                                  "code": authorization_code,
                                  "redirect_uri": self.redirect_uri})

    def grant_token_via_refresh(self, refresh_token):
        return self._grant_token({"grant_type": "refresh_token",
                                  "refresh_token": refresh_token})
