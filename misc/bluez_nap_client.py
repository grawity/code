#!/usr/bin/env python3
import argparse
import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
import os
from pprint import pprint
import subprocess

SERVICE_UUID = {"nap":  "00001116-0000-1000-8000-00805f9b34fb",
                "panu": "00001115-0000-1000-8000-00805f9b34fb"}

class Bluez():
    def __init__(self, bus):
        self.bus = bus

    def get_object(self, path):
        return self.bus.get_object("org.bluez", path)

    def get_objects(self):
        om = dbus.Interface(self.get_object("/"),
                            "org.freedesktop.DBus.ObjectManager")
        # {path -> {interface -> {property -> value}}}
        return om.GetManagedObjects()

    def find_first_adapter(self):
        for obj_path, obj_ifaces in self.get_objects().items():
            if "org.bluez.Adapter1" not in obj_ifaces:
                continue
            return obj_path, obj_ifaces["org.bluez.Adapter1"]

    def find_device_by_addr(self, addr):
        addr = addr.upper().replace("-", ":")
        for obj_path, obj_ifaces in self.get_objects().items():
            if "org.bluez.Device1" not in obj_ifaces:
                continue
            if obj_ifaces["org.bluez.Device1"]["Address"] != addr:
                continue
            return obj_path, obj_ifaces["org.bluez.Device1"]

parser = argparse.ArgumentParser()
parser.add_argument("-S", "--server", action="store_true",
                    help="register a server")
parser.add_argument("-C", "--client", metavar="SERVER_ADDR",
                    help="connect to a server")
parser.add_argument("-b", "--bridge", default="br0",
                    help="bridge to use for NAP mode")
parser.add_argument("-e", "--service", default="nap",
                    help="service name ('nap' or 'panu')")
args = parser.parse_args()

DBusGMainLoop(set_as_default=True)

bus = dbus.SystemBus()
bz = Bluez(bus)

if args.service not in {"nap", "panu"}:
    exit("error: Only 'nap' and 'panu' are valid service types.")

if args.server and args.client:
    exit("error: Only one mode option may be specified.")

elif args.server:
    if not os.path.exists(f"/sys/class/net/{args.bridge}"):
        print(f"Bridge interface {args.bridge!r} missing; trying to create.")
        subprocess.run(["ip", "link", "add", args.bridge, "type", "bridge"])
        subprocess.run(["ip", "link", "set", args.bridge, "up"])

    adp_path, adp_props = bz.find_first_adapter()
    adp_addr = adp_props["Address"]
    print(f"Using adapter {adp_addr} ({adp_path})")

    print("Registering service...")
    server = dbus.Interface(bz.get_object(adp_path), "org.bluez.NetworkServer1")
    server.Register(args.service, args.bridge)

    print(f"Registered {args.service.upper()} on {args.bridge}. Press Ctrl+C to exit.")
    GLib.MainLoop().run()

elif args.client:
    dev_path, dev_props = bz.find_device_by_addr(args.client)
    dev_addr = dev_props["Address"]
    print(f"Using device {dev_addr} ({dev_path})")

    if SERVICE_UUID[args.service] not in dev_props["UUIDs"]:
        print("Probing profile...")
        device = dbus.Interface(bz.get_object(dev_path), "org.bluez.Device1")
        try:
            device.ConnectProfile(args.service)
        except Exception as e:
            print(e)

    print("Establishing connection...")
    device = dbus.Interface(bz.get_object(dev_path), "org.bluez.Network1")
    netif = device.Connect(args.service)

    print(f"Connected to {args.service.upper()} as {netif!r}. Press Ctrl+C to exit.")
    try:
        GLib.MainLoop().run()
    except KeyboardInterrupt:
        print("Disconnecting.")
        device.Disconnect()

else:
    exit("error: A mode option must be specified.")
