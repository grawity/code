import win32api as Api
import win32con as Con

def load_string_resource(pointer):
    """Resolve a @dllname,ordinal string resource pointer"""

    if pointer[0] != "@":
        return pointer

    resfile, resid = pointer[1:].split(",")
    resid = int(resid)

    hRes = Api.LoadLibraryEx(resfile, 0, Con.LOAD_LIBRARY_AS_DATAFILE)
    val = Api.LoadString(hRes, -resid, 1024)
    Api.FreeLibrary(hRes)

    return val.split('\x00', 1)[0]
