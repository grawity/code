#!/usr/bin/env python3
# rdp -- launch FreeRDP to make Remote Desktop connections
import argparse
from nullroute.core import Core
import os
import socket
import subprocess
import sys

def die(msg):
    if sys.stdin.isatty():
        exit("error: %s" % msg)
    else:
        msg = msg.replace("&", "&amp;") \
                 .replace("<", "&lt;") \
                 .replace(">", "&gt;")
        subprocess.run(["zenity", "--error",
                                  "--title=mstsc",
                                  "--text=<b>Error:</b> %s" % msg,
                                  "--width=300"])
        exit(1)

def safe(args):
    nargs = []
    for arg in args:
        if arg.startswith("/p:"):
            arg = "/p:" + "*"*(len(arg)-len("/p:"))
        nargs.append(arg)
    return nargs

def resolve(host):
    fqdn = None
    addrs = []
    res = socket.getaddrinfo(host, 3389,
                             type=socket.SOCK_STREAM,
                             flags=socket.AI_CANONNAME)
    for ai_af, _, _, ai_fqdn, ai_addr in res:
        if ai_fqdn:
            fqdn = ai_fqdn
        addrs.append(ai_addr[0])
    if not fqdn:
        fqdn, addrs = resolve_harder(host, prefixes)
    return fqdn, addrs

def get_credentials_zenity(text):
    res = subprocess.run(["zenity",
                          "--forms",
                          "--title", "Enter credentials",
                          "--text", "Enter credentials for %s:" % text,
                          "--add-entry", "Username:",
                          "--add-password", "Password:",
                          "--separator", "\n"],
                         stdout=subprocess.PIPE)
    Core.debug("Zenity output: %r", res.stdout)
    username, password, _ = res.stdout.decode().split("\n")
    return username, password

def get_credentials(host):
    import gi
    gi.require_version("Secret", "1")
    from gi.repository import GLib
    from gi.repository import Secret

    targets = [host]
    if len(host.split(".")) >= 3:
        _, domain = host.split(".", 1)
        targets = [host, "*." + domain]

    for target in targets:
        for proto in ["rdp", "smb"]:
            qattrs = {"xdg:schema": "org.gnome.keyring.NetworkPassword",
                      "protocol": proto,
                      "server": target}
            Core.debug("Searching libsecret for attrs %r", qattrs)
            res = Secret.password_search_sync(None,
                                              qattrs,
                                              Secret.SearchFlags.LOAD_SECRETS,
                                              None)
            if res:
                Core.debug("Found libsecret credential %r", res[0].get_label())
                for k, v in sorted(res[0].get_attributes().items()):
                    Core.debug("Attribute: %s = %r", k, v)
                username = res[0].get_attributes()["user"]
                password = res[0].get_secret().get_text()
                if domain := res[0].get_attributes().get("domain"):
                    if "." in domain:
                        username = "%s@%s" % (username, domain)
                    else:
                        username = "%s\\%s" % (domain, username)
                return username, password

    print("Credentials not found, asking interactively")
    return get_credentials_zenity("Remote Desktop on %s" % host)

parser = argparse.ArgumentParser()
parser.add_argument("--legacy", "--old",
                    action="store_true",
                    help="legacy server (Windows 2003 or older, non-NLA)")
parser.add_argument("--restricted-admin", "--ra",
                    action="store_true",
                    help="Restricted Admin mode - don't delegate any credentials")
parser.add_argument("--workarea",
                    action="store_true",
                    help="fit display into the work area instead of full-screen")
parser.add_argument("--gfx",
                    action="store_true",
                    help="enable support for RDP8 \"Graphics Pipeline\"")
parser.add_argument("--rfx",
                    action="store_true",
                    help="enable support for RDP7 \"RemoteFX\" graphics")
parser.add_argument("--dev",
                    action="store_true",
                    help="use local FreeRDP build if available")
parser.add_argument("--no-wayland",
                    action="store_true",
                    help="disable Wayland even if available (use X11)")
parser.add_argument("host")
args = parser.parse_args()

Core.debug("trying to resolve host %r", args.host)
fqdn, addrs = resolve(args.host)
Core.debug("resolved to fqdn %r, addresses %r", fqdn, addrs)

username, password = get_credentials(fqdn)

if os.environ.get("WAYLAND_DISPLAY"):
    cmd = ["wlfreerdp"]
else:
    cmd = ["xfreerdp"]

cmd.append("/t:Remote Desktop: %s" % args.host)
cmd.append("/v:%s" % fqdn)
#cmd.append("/cert:name:%s" % fqdn)

cmd.append("/u:%s" % username)
cmd.append("/p:%s" % password)

if args.legacy:
    cmd.append("/cert:ignore")
    cmd.append("+sec-rdp")
    cmd.append("+sec-tls")
    if args.restricted_admin:
        die("Restricted Admin mode is not supported by legacy servers")
else:
    cmd.append("/ipv6")
    cmd.append("-sec-rdp")
    cmd.append("-sec-tls")
    if args.restricted_admin:
        cmd.append("/restricted-admin")

cmd.append("/network:auto")
#cmd.append("/gfx:avc420")
#cmd.append("/bpp:32")
#cmd.append("+fonts")
#cmd.append("+aero")
#cmd.append("+window-drag")
#cmd.append("+wallpaper")
cmd.append("+multitouch")

cmd.append("/sound:sys:pulse")
cmd.append("+clipboard")
#cmd.append("+home-drive")
#cmd.append("/drive:media,/run/media/%s" % os.getlogin())
#cmd.append("/smartcard")

if args.workarea:
    cmd.append("/workarea")
    cmd.append("-decorations")
else:
    cmd.append("/f")
    cmd.append("+floatbar")

print(safe(cmd))
subprocess.run(cmd)
