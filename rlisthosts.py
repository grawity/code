#!/usr/bin/env python3
# rlisthosts -- helper for rdo/rup to discover hosts
#
# Might use LDAP one day, but for now it's just a static list (instead of
# having that list hardcoded in rup, then copied to other tools).

import argparse

base_hosts = ["wolke", "sky", "star", "land", "ember", "wind"]
other_hosts = ["vm-vol5", "vm-litnet"]

parser = argparse.ArgumentParser()
parser.add_argument("-a", action="store_true",
                          help="include primary containers")
parser.add_argument("host", nargs="*")
args = parser.parse_args()

hosts = base_hosts[:]
if args.a:
    hosts += other_hosts[:]

if args.host:
    arg_hosts = " ".join(args.host).replace(",", " ")
    if arg_hosts.startswith("+"):
        hosts += arg_hosts[1:].split()
    else:
        hosts = arg_hosts.split()

print(*hosts)
