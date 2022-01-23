#!/usr/bin/env python3
# rlisthosts -- helper for rup to discover hosts
#
# Might use LDAP one day, but for now it's just a static list (instead of
# having that list hardcoded in rup, then copied to other tools).
import argparse

base_hosts = ["wolke", "sky", "star", "land", "ember", "wind"]
other_hosts = ["vm-vol5", "vm-litnet"]

parser = argparse.ArgumentParser()
parser.add_argument("-a", action="store_true",
                          help="include primary containers")
args = parser.parse_args()

hosts = base_hosts[:]
if args.a:
    hosts += other_hosts[:]

print(*hosts)
