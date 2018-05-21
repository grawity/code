import win32con as Con
from .registry import RegistryKey

class Firewall(object):
    ROOT_KEY = "SYSTEM\\CurrentControlSet\\Services\\SharedAccess\\Parameters\\FirewallPolicy\\StandardProfile"

    SCOPE_ALL       = "*"
    SCOPE_SUBNET    = "LocalSubNet"

    status_ENABLED  = "Enabled"
    status_DISABLED = "Disabled"

    def __init__(self, machine=None):
        self.machine = machine
        self.hKey = RegistryKey(Con.HKEY_LOCAL_MACHINE, path=self.ROOT_KEY,
                                machine=self.machine)

        self._appList = None
        self._portList = None

    @property
    def apps(self):
        if not self._appList:
            self._appList = _FirewallApplicationList(self)
        return self._appList

    @property
    def ports(self):
        if not self._portList:
            self._portList = _FirewallPortList(self)
        return self._portList

class _FirewallApplicationList(object):
    APPS_SUBKEY = "AuthorizedApplications\\List"

    POS_EXEPATH = 0
    POS_SCOPE   = 1
    POS_status  = 2
    POS_NAME    = 3

    def __init__(self, fw):
        self.fwProfile = fw
        self.hKey = self.fwProfile.hKey.open_subkey(self.APPS_SUBKEY)

    @classmethod
    def _pack(self, exepath, scope=None, enabled=None, name=None):
        if scope is not None:
            status = "Enabled" if enabled else "Disabled"
            return ":".join([exepath, scope, status, name])
        else:
            return exepath

    @classmethod
    def _unpack_value(self, val):
        return val

    @classmethod
    def _unpack_data(self, val):
        # deal with drive:\path bogosity
        _drive, _rest = val[:2], val[2:]
        exepath, scope, status, name = _rest.split(":", 3)
        exepath = _drive + exepath
        enabled = (status.lower() == "enabled")
        return exepath, scope, enabled, name

    # Lookup

    def query(self, exepath):
        value = self._pack(exepath)
        data, _reg_type = self.hKey[value]
        return self._unpack_data(data)

    def __getitem__(self, key):
        return self.query(key)

    def set(self, exepath, scope, enabled, name):
        scope = scope or self.SCOPE_ALL
        value = self._pack(exepath)
        data = self._pack(exepath, scope, enabled, name)
        self.hKey[value] = (data, Con.REG_SZ)

    def __setitem__(self, key, val):
        if val[0] != key:
            raise ValueError("exepath must be identical to the key")
        self.set(*val)

    def delete(self, exepath):
        value = self._pack(exepath)
        del self.hKey[value]

    def __delitem__(self, key):
        self.delete(key)

    def __iter__(self):
        for k, (v, t) in self.hKey:
            yield self._unpack_value(k)

    def values(self):
        for k, (v, t) in self.hKey:
            yield self._unpack_data(v)

    def items(self):
        for k, (v, t) in self.hKey:
            yield self._unpack_value(k), self._unpack_data(v)

class _FirewallPortList(object):
    PORTS_SUBKEY    = "GloballyOpenPorts\\List"

    #POS_PORT   = 0
    #POS_PROTO  = 1
    #POS_SCOPE  = 2
    #POS_status = 3
    #POS_NAME   = 4

    POS_PORTSPEC    = 0
    POS_SCOPE       = 1
    POS_status      = 2
    POS_NAME        = 3

    def __init__(self, fw):
        self.fwProfile = fw
        self.hKey = self.fwProfile.hKey.open_subkey(self.PORTS_SUBKEY)

    @classmethod
    def _pack(self, portspec, scope=None, enabled=None, name=None):
        try:
            port, proto = portspec
        except (TypeError, ValueError) as e:
            raise ValueError("portspec must be (port, protocol)")
        port = str(port)
        proto = proto.upper()
        if scope is not None:
            status = "Enabled" if enabled else "Disabled"
            return ":".join([port, proto, scope, status, name])
        else:
            return ":".join([port, proto])

    @classmethod
    def _unpack_value(self, val):
        port, proto = val.split(":", 1)
        port = int(port)
        proto = proto.upper()
        return port, proto

    @classmethod
    def _unpack_data(self, val):
        port, proto, scope, status, name = val.split(":", 4)
        port = int(port)
        proto = proto.upper()
        enabled = (status.lower() == "enabled")
        return (port, proto), scope, enabled, name

    @classmethod
    def _verify_key(self, key):
        try:
            assert len(key) == 2
        except (TypeError, AssertionError):
            raise KeyError("key must be a (port, proto)")

    # Dict-like lookup

    def query(self, portspec):
        value = self._pack(portspec)
        data, _reg_type = self.hKey[value]
        return self._unpack_data(data)

    def __getitem__(self, key):
        return self.query(key)

    def set(self, portspec, scope, enabled, name):
        scope = scope or self.SCOPE_ALL
        value = self._pack(portspec)
        data = self._pack(portspec, scope, enabled, name)
        self.hKey[value] = (data, Con.REG_SZ)

    def __setitem__(self, key, val):
        if val[0] != key:
            raise ValueError("portspec must be identical to key")
        self.set(*val)

    def delete(self, portspec):
        value = self._pack(portspec)
        del self.hKey[value]

    def __delitem__(self, key):
        self.delete(key)

    def __iter__(self):
        for k, (v, t) in self.hKey:
            yield self._unpack_value(k)

    def values(self):
        for k, (v, t) in self.hKey:
            yield self._unpack_data(v)

    def items(self):
        for k, (v, t) in self.hKey:
            yield self._unpack_value(k), self._unpack_data(v)

    # Rule management

    def get_rule_status(self, portspec):
        return self[portspec][self.POS_STATUS]

    def set_rule_status(self, portspec, enabled):
        _, scope, _, name = self[portspec]
        self[portspec] = portspec, scope, enabled, name

    def get_rule_name(self, portspec):
        return self[portspec][self.POS_NAME]

    def set_rule_name(self, portspec, name):
        _, scope, enabled, _ = self[portspec]
        self[portspec] = portspec, scope, enabled, name
