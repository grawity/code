import nullroute.sec
import xmlrpc.client

class NullPointerException(Exception):
    pass

class NoSuchDomainException(Exception):
    pass

# IceWarpProxy {{{
class IceWarpProxy(object):
    _types_ = {
        "None->Create": "APIObject",
        "APIObject->NewDomain": "DomainObject",
        "APIObject->OpenDomain": "DomainObject",
        "DomainObject->NewAccount": "AccountObject",
        "DomainObject->OpenAccount": "AccountObject",
    }

    def __init__(self, api, ptr, type):
        self.api = api
        self.ptr = ptr
        self.type = type or "None"

    @classmethod
    def new(self, api, ptr, type):
        if ptr and ptr != "0":
            return self(api, ptr, type)
        else:
            return None

    def __getattr__(self, name):
        func = getattr(self.api.xmlrpc_proxy, "%s->%s" % (self.ptr, name))
        if self.type is None and name == "Create":
            def wrap(*args):
                if len(args):
                    type = args[0].split(".")[-1]
                else:
                    type = None
                ptr = func(*args)
                return IceWarpProxy.new(self.api, ptr, type)
            return wrap
        else:
            type = self._types_.get("%s->%s" % (self.type, name))
            if type:
                def wrap(*args):
                    ptr = func(*args)
                    return IceWarpProxy.new(self.api, ptr, type)
                return wrap
            else:
                return func

    def __repr__(self):
        return "<IceWarpProxy [%s %r]>" % (self.type, self.ptr)
# }}}

# IceWarpAPI {{{
class IceWarpAPI(object):
    def __init__(self, api_url):
        self.xmlrpc_proxy = xmlrpc.client.ServerProxy(api_url)
        self.null_object = IceWarpProxy(self, "0", None)
        self.api_object = self.null_object.Create("IceWarpServer.APIObject")
        
        self._domains = {}
        self._accounts = {}

    def __getattr__(self, name):
        return getattr(self.api_object, name)

    def OpenDomain(self, domain):
        if domain not in self._domains:
            self._domains[domain] = self.api_object.OpenDomain(domain)
        return self._domains[domain]

    def OpenAccount(self, domain, alias):
        acct = "%s@%s" % (domain, alias)
        if acct not in self._accounts:
            domain_object = self.OpenDomain(domain)
            if not domain_object:
                raise NoSuchDomainException(domain)
            self._accounts[acct] = domain_object.OpenAccount(alias)
        return self._accounts[acct]
# }}}

def connect(server, login=None, password=None):
    if login:
        api_creds = {"login": login, "password": password, "machine": server}
    else:
        api_creds = nullroute.sec.get_netrc("api/%s" % server)
        api_creds["machine"] = server
    api_base = "https://%(login)s:%(password)s@%(machine)s/rpc/" % api_creds
    return IceWarpAPI(api_base)
