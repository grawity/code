import pywintypes
import win32api as Api
import win32con as Con

def load_external_string(pointer):
	if pointer[0] != "@":
		return pointer

	resfile, resid = pointer[1:].split(",")
	resid = int(resid)

	hRes = Api.LoadLibraryEx(resfile, 0, Con.LOAD_LIBRARY_AS_DATAFILE)
	val = Api.LoadString(hRes, -resid, 1024)
	Api.FreeLibrary(hRes)

	return val.split('\x00', 1)[0]

class RegistryKey(object):
	def __init__(self, hKey, path=None, machine=None):
		self.access = Con.KEY_ALL_ACCESS
		if isinstance(hKey, pywintypes.HANDLEType):
			if path is None:
				self.hKey = hKey
				self.path = None
			else:
				self.hKey = Api.RegOpenKeyEx(hKey, path, 0, self.access)
				self.path = path
			self.machine = None
		else:
			if machine is None:
				self.hKey = Api.RegOpenKeyEx(hKey, path, 0, self.access)
				self.path = path
			else:
				if not machine.startswith("\\\\"):
					machine = "\\\\%s" % machine
				hKey = Api.RegConnectRegistry(machine, hKey)
				if path is None:
					self.hKey = hKey
				else:
					self.hKey = Api.RegOpenKeyEx(hKey, path, 0, self.access)
				self.path = path
			self.machine = machine

	def close(self):
		if self.hKey:
			Api.RegCloseKey(self.hKey)
			self.hKey = None

	def __del__(self):
		self.close()

	def query(self, valueName):
		try:
			return Api.RegQueryValueEx(self.hKey, valueName)
		except pywintypes.error as e:
			if e.winerror == 2:
				raise KeyError(valueName)
			else:
				raise

	def __getitem__(self, valueName):
		return self.query(valueName)

	def set(self, valueName, valueType, valueData):
		return Api.RegSetValueEx(self.hKey, valueName, None, valueType, valueData)

	def __setitem__(self, valueName, valueTypedData):
		valueData, valueType = valueTypedData
		return self.set(valueName, valueType, valueData)

	def delete(self, valueName):
		return Api.RegDeleteValue(self.hKey, valueName)

	def __delitem__(self, valueName):
		return self.delete(valueName)

	def enumerate(self):
		i = 0
		while True:
			try:
				value, data, type = Api.RegEnumValue(self.hKey, i)
			except Api.error:
				break
			else:
				yield value, (data, type)
				i += 1

	def __iter__(self):
		return self.enumerate()

	def openSubkey(self, path):
		return self.__class__(self.hKey, path)

class Firewall(object):
	ROOT_KEY = "SYSTEM\\CurrentControlSet\\Services\\SharedAccess\\Parameters\\FirewallPolicy\\StandardProfile"

	SCOPE_ALL	= "*"
	SCOPE_SUBNET	= "LocalSubNet"

	STATE_ENABLED	= "Enabled"
	STATE_DISABLED	= "Disabled"

	def __init__(self, machine=None):
		self.machine = machine
		self.hKey = RegistryKey(Con.HKEY_LOCAL_MACHINE, path=self.ROOT_KEY,
					machine=self.machine)

		self._portList = None

	@property
	def ports(self):
		if not self._portList:
			self._portList = _FirewallPortList(self)
		return self._portList

class _FirewallApplicationList(object):
	#APPS_SUBKEY	= "AuthorizedApplica

	pass

class _FirewallPortList(object):
	PORTS_SUBKEY	= "GloballyOpenPorts\\List"

	POS_PORT	= 0
	POS_PROTO	= 1
	POS_SCOPE	= 2
	POS_STATE	= 3
	POS_NAME	= 4

	def __init__(self, fw):
		self.fwProfile = fw
		self.hKey = self.fwProfile.hKey.openSubkey(self.PORTS_SUBKEY)

	@classmethod
	def _pack(self, port, proto, scope=None, enabled=None, name=None):
		port = str(port)
		proto = proto.upper()
		if scope is not None:
			state = "Enabled" if enabled else "Disabled"
			return ":".join([port, proto, scope, enabled, name])
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
		port, proto, scope, mode, name = val.split(":", 4)
		port = int(port)
		proto = proto.upper()
		enabled = (mode.lower() == "enabled")
		if name.startswith("@") and "," in name:
			name = load_external_string(name)
		return port, proto, scope, enabled, name

	@classmethod
	def _verify_key(self, key):
		try:
			assert len(key) == 2
		except (TypeError, AssertionError):
			raise KeyError("key must be a (port, proto)")

	def query(self, port, proto):
		value = self._pack(port, proto)
		data, _reg_type = self.hKey[value]
		return self._unpack_data(data)

	def __getitem__(self, key):
		self._verify_key(key)
		return self.query(*key)[2:]

	def set(self, port, proto, scope, enabled, name):
		scope = scope or self.SCOPE_ALL
		enabled = "Enabled" if enabled else "Disabled"

		value = self._pack(port, proto)
		data = self._pack(port, proto, scope, enabled, name)
		self.hKey[value] = (data, Con.REG_SZ)
	def __setitem__(self, key, value):
		self._verify_key(key)
		if len(value) == 3:
			self.set(*(key + value))
		elif len(value) == 5:
			if key != value[:2]:
				raise ValueError("(port, proto) in value do not match key")
			self.set(*(key + value[2:]))
		else:
			raise ValueError("value must be a 5-tuple")

	def delete(self, port, proto):
		value = self._pack(port, proto)
		del self.hKey[value]


	def __delitem__(self, key):
		self._verify_key(key)
		self.delete(*key)

	def enumerate(self):
		for k, (v, t) in self.hKey:
			yield self._unpack_data(v)

	def __iter__(self):
		for k, (v, t) in self.hKey:
			yield self._unpack_value(k)

	def items(self):
		for k, (v, t) in self.hKey:
			v = self._unpack_data(v)
			yield v[:2], v[2:]

	def enable(self, port, proto, enabled=True):
		port, proto = scope, _, name = self[port, proto]
		self[port, proto] = (scope, enabled, name)
