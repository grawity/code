import base64
import hashlib
import json
import os
import time
import urllib.parse
import urllib.request

# Specifications:
#   - PKCE (https://datatracker.ietf.org/doc/html/rfc7636)

# Special redirect URI that indicates manual copy-paste
OOB_REDIRECT_URI = "urn:ietf:wg:oauth:2.0:oob"

def generate_verifier(length=64):
    if not (43 <= length <= 128):
        raise ValueError("length out of bounds")
    buf = os.urandom((length + 1) * 3 // 4)
    buf = base64.urlsafe_b64encode(buf)
    assert len(buf) >= length
    return buf[:length].decode()

def generate_s256_challenge(verifier):
    buf = verifier.encode()
    buf = hashlib.sha256(buf).digest()
    buf = base64.urlsafe_b64encode(buf)
    return buf.rstrip(b"=").decode()

def format_http_basic_auth(username, password):
    buf = ("%s:%s" % (username, password)).encode()
    buf = base64.b64encode(buf).decode()
    return "Basic %s" % buf

class OAuth2Client():
    def __init__(self, client_id,
                       client_secret=None,
                       discovery_url=None,
                       authorization_url=None,
                       token_grant_url=None,
                       device_authz_url=None,
                       redirect_url=None):
        self.client_id = client_id
        self.client_secret = client_secret
        self.discovery_url = discovery_url,
        self.authorization_url = authorization_url
        self.device_authz_url = device_authz_url
        self.token_grant_url = token_grant_url
        self.redirect_uri = redirect_url or OOB_REDIRECT_URI
        self.pkce_verifier = generate_verifier()

    def _discover_endpoints(self):
        # OIDC-specific; implemented by Google (at "accounts.google.com") but not GitHub
        if not self.discovery_url:
            raise ValueError("either discovery URL or endpoint URLs must be specified")
        discovery_url = urllib.parse.urljoin(self.discovery_url, ".well-known/openid-configuration")
        response = urllib.request.urlopen(discovery_url).read()
        response = json.loads(response)
        if not self.authorization_url:
            self.authorization_url = response["authorization_endpoint"]
        if not self.token_grant_url:
            self.token_grant_url = response["token_endpoint"]
        if not self.device_authz_url:
            self.device_authz_url = response.get("device_authorization_endpoint", None)

    def make_authorization_url(self, scope):
        if not self.authorization_url:
            self._discover_endpoints()
        params = {"client_id": self.client_id,
                  "response_type": "code",
                  "redirect_uri": self.redirect_uri,
                  "scope": scope,
                  # Use PKCE to compensate for the client_secret not being secret.
                  "code_challenge": generate_s256_challenge(self.pkce_verifier),
                  "code_challenge_method": "S256"}
        # See OAUTH 5.1 for a definition of which characters need to be escaped
        params = urllib.parse.urlencode(params,
                                        quote_via=urllib.parse.quote,
                                        safe="~-._")
        return "%s?%s" % (self.authorization_url, params)

    def _grant_token(self, post_data, *,
                           use_http_auth=True):
        if not self.token_grant_url:
            self._discover_endpoints()
        if not use_http_auth:
            post_data |= {"client_id": self.client_id,
                          "client_secret": self.client_secret}
        post_data = urllib.parse.urlencode(post_data).encode()
        request = urllib.request.Request(self.token_grant_url)
        if use_http_auth:
            request.add_header("Authorization", format_http_basic_auth(self.client_id,
                                                                       self.client_secret))
        request.add_header("Accept", "application/json")
        response = urllib.request.urlopen(request, post_data).read()
        response = json.loads(response)
        if exp := response.get("expires_in"):
            response.setdefault("expires_at", int(time.time() + exp))
        return response

    def grant_token_via_authorization(self, authorization_code):
        return self._grant_token({"grant_type": "authorization_code",
                                  "code": authorization_code,
                                  "code_verifier": self.pkce_verifier,
                                  "redirect_uri": self.redirect_uri})

    def grant_token_via_refresh(self, refresh_token):
        return self._grant_token({"grant_type": "refresh_token",
                                  "refresh_token": refresh_token})

    def _device_authz(self):
        """
        Get a temporary device token using 'Device Authorization' grant.
        https://datatracker.ietf.org/doc/html/rfc8628
        """
        if not self.device_authz_url:
            self._discover_endpoints()
        if not self.device_authz_url:
            raise Exception("IdP does not have Device Authorization endpoint")
        post_data = {}
        if not use_http_auth:
            post_data |= {"client_id": self.client_id,
                          "client_secret": self.client_secret}
        post_data = urllib.parse.urlencode(post_data).encode()
        if use_http_auth:
            request.add_header("Authorization", format_http_basic_auth(self.client_id,
                                                                       self.client_secret))
        request.add_header("Accept", "application/json")
        response = urllib.request.urlopen(request, post_data).read()
        response = json.loads(response)
        raise Exception(str(response))

        # try:
        # url = response["verification_url"]
        # except KeyError:
        # hack from Step-CLI: Google uses nonstandard key '_uri' instead of '_url', use as fallback
        # url = response["verification_uri"]
        #
        # print("Go to the following website:")
        # print(url)
        # print("and enter the activation code:")
        # print(user_code)
        #
        # Poll token endpoint every 5 seconds (for 5 minutes max)
        #self._grant_token({"grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        #                   "device_code": device_code})
