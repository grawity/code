import pywintypes
import win32api as Api
import win32con as Con

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

    def open_subkey(self, path):
        return self.__class__(self.hKey, path)
