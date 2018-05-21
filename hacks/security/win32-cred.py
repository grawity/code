#!python
# win32-cred - Windows credential management tool
from __future__ import print_function
import sys
import getopt
import pywintypes
from win32cred import *

ERROR_NOT_FOUND                 = 0x490
ERROR_NO_SUCH_LOGON_SESSION     = 0x520
ERROR_INVALID_FLAGS             = 0x3ec

CRED_TYPE_DOMAIN_EXTENDED       = 0x6
CRED_ENUMERATE_ALL_CREDENTIALS  = 0x1

CredPersist = {
    "no":           0,
    "session":      CRED_PERSIST_SESSION,
    "local":        CRED_PERSIST_LOCAL_MACHINE,
    "enterprise":   CRED_PERSIST_ENTERPRISE,
}
CredType = {
    "generic":      CRED_TYPE_GENERIC,
    "domain":       CRED_TYPE_DOMAIN_PASSWORD,
    "domcert":      CRED_TYPE_DOMAIN_CERTIFICATE,
    "passport":     CRED_TYPE_DOMAIN_VISIBLE_PASSWORD,
    "domext":       CRED_TYPE_DOMAIN_EXTENDED,
}
CredFlags = {
    "username-target":  CRED_FLAGS_USERNAME_TARGET
}

def handleWinError(e):
    (code, func, error) = e
    print("error: %s: [%d] %s" % (func, code, error), file=sys.stderr)

def findkey(haystack, needle, default=None):
    for k, v in haystack.items():
        if v == needle:
            return k
    return default

def display(cred, full=True):
    cType = findkey(CredType, cred["Type"], "unknown")
    cPersist = findkey(CredPersist, cred["Persist"], "unknown")
    cFlags = [flag for flag, value in CredFlags.items() if cred["Flags"] & value]
    cBlob = cred["CredentialBlob"]

    if full:
        fmt = "%12s %s"
        print(fmt % ("target:", cred["TargetName"]))
        if cred["TargetAlias"] is not None:
            for a in cred["TargetAlias"]:
                print(fmt % ("alias:", a))
        print(fmt % ("type:", cType))
        print(fmt % ("user:", cred["UserName"]))
        print(fmt % ("comment:", cred["Comment"]))
        print(fmt % ("persist:", cPersist))
        for flag in cFlags:
            print(fmt % ("flags:", flag))
        for attr in cred["Attributes"]:
            text = "%(Keyword)s=%(Value)s" % attr
            print(fmt % ("attribute:", text))
        if cBlob:
            print(fmt % ("blob:", "<%d bytes>" % len(cBlob)))
            #print(fmt % ("", repr(cBlob)))
        print()
    else:
        trim = lambda string, n: string[:n-3]+"..." if len(string) > n else string
        print("%(TargetName)-30s %(UserName)-30s %(Type)-8s %(Persist)-3s" % {
            "TargetName":   trim(cred["TargetName"], 30),
            "UserName":     trim(cred["UserName"], 30),
            "Type":         cType,
            "Persist":      cPersist[:7],
        })


cred = {
    "TargetName":   None,
    "UserName": None,
    "Persist":  CredPersist["local"],
    "Type":     CredType["generic"],
    "Comment":  None,
    "Attributes":   {},
    "Flags":    0,
}
require = set()

try:
    action = sys.argv[1]
except IndexError:
    print("Usage:")
    print("  cred {ls | ll} [targetprefix]")
    print("  cred {new | rm | read | readdom | targetinfo} <target> [-t type] [-r require]")
    sys.exit(2)

options, rest = getopt.gnu_getopt(sys.argv[2:], "a:c:f:P:r:t:u:")

for opt, arg in options:
    if opt == "-a":
        key, value = arg.split("=", 1)
        cred["Attributes"][key] = value
    elif opt == "-c":
        cred["Comment"] = arg
    elif opt == "-f":
        if arg in CredFlags:
            cred["Flags"] |= CredFlags[arg]
        else:
            raise ValueError("Unknown flag %r" % arg)
    elif opt == "-P":
        if arg in CredPersist:
            cred["Persist"] = CredPersist[arg]
        else:
            raise ValueError("Invalid persist value %r" % arg)
    elif opt == "-r":
        if arg in ("admin", "nocert", "cert", "sc"):
            require.add(arg)
    elif opt == "-t":
        if arg in CredType:
            cred["Type"] = CredType[arg]
        else:
            raise ValueError("Invalid type %r" % arg)
    elif opt == "-u":
        cred["UserName"] = arg

if action in ("ls", "ll"):
    full = (action == "ll")
    try:
        filter = rest.pop(0)+"*"
    except IndexError:
        filter = None
    flags = 0
    try:
        if full:
            for cred in CredEnumerate(filter, flags):
                display(cred, True)
                print
        else:
            print("%-30s %-30s %-8s %-3s" % ("Target", "User", "Type", "Persist"))
            print("-"*79)
            for cred in CredEnumerate(filter, flags):
                display(cred, False)
    except pywintypes.error as e:
        if e[0] == ERROR_NOT_FOUND:
            print("No credentials stored.")
        else:
            handleWinError(e)
elif action == "new":
    cred["TargetName"] = rest.pop(0)
    flags = 0
    flags |= CREDUI_FLAGS_DO_NOT_PERSIST

    if cred["Type"] == CRED_TYPE_GENERIC:
        flags |= CREDUI_FLAGS_GENERIC_CREDENTIALS
        flags |= CREDUI_FLAGS_ALWAYS_SHOW_UI
    elif cred["Type"] == CRED_TYPE_DOMAIN_PASSWORD:
        flags |= CREDUI_FLAGS_EXCLUDE_CERTIFICATES
    elif cred["Type"] == CRED_TYPE_DOMAIN_CERTIFICATE:
        flags |= CREDUI_FLAGS_REQUIRE_CERTIFICATE

    if cred["Flags"] & CRED_FLAGS_USERNAME_TARGET:
        flags |= CREDUI_FLAGS_USERNAME_TARGET_CREDENTIALS
        cred["UserName"] = cred["TargetName"]

    if "cert" in require:
        flags |= CREDUI_FLAGS_REQUIRE_CERTIFICATE
    if "sc" in require:
        flags |= CREDUI_FLAGS_REQUIRE_SMARTCARD
    if "nocert" in require:
        flags |= CREDUI_FLAGS_EXCLUDE_CERTIFICATES
    if "admin" in require:
        flags |= CREDUI_FLAGS_REQUEST_ADMINISTRATOR

    try:
        user, blob, persist = CredUIPromptForCredentials(
            cred["TargetName"], 0, cred["UserName"], None, False, flags)
        cred["UserName"], cred["CredentialBlob"] = user, blob
        CredWrite(cred)
    except pywintypes.error as e:
        handleWinError(e)
    else:
        cred = CredRead(cred["TargetName"], cred["Type"])
        display(cred)
elif action == "add":
    cred["TargetName"] = rest.pop(0)
    CredWrite(cred)
elif action == "rm":
    cred["TargetName"] = rest.pop(0)
    try:
        CredDelete(cred["TargetName"], cred["Type"])
    except pywintypes.error as e:
        handleWinError(e)
elif action == "read":
    cred["TargetName"] = rest.pop(0)
    try:
        cred = CredRead(cred["TargetName"], cred["Type"])
        display(cred)
    except pywintypes.error as e:
        handleWinError(e)
elif action == "readdom":
    ttype, tname = rest.pop(0).split(":", 1)
    keys = {
        "target":       "TargetName",
        "nbserver":     "NetbiosServerName",
        "nbdomain":     "NetbiosDomainName",
        "server":       "DnsServerName",
        "domain":       "DnsDomainName",
        "tree":         "DnsTreeName",
    }
    key = keys.get(ttype, keys["target"])
    try:
        for cred in CredReadDomainCredentials({key: tname}):
            display(cred)
    except pywintypes.error as e:
        handleWinError(e)
elif action == "targetinfo":
    for target in rest:
        info = CredGetTargetInfo(target)
        keys = info.keys()
        keys.sort()
        keys.remove("TargetName")
        keys.insert(0, "TargetName")
        for key in keys:
            value = info[key]
            if key == "CredTypes":
                value = ", ".join(findkey(CredType, i, str(i))
                    for i in value) if value else None
            elif key == "Flags":
                flags = set()
                if value & CRED_ALLOW_NAME_RESOLUTION:
                    flags.add("allow name resolution")
                value = ", ".join(flags) if flags else None
            print("%18s: %s" % (key, value or ""))
        print()
else:
    print("Error: Unknown action %r" % action)
