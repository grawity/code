#!/usr/bin/env python3
# hi -- show recent IRC highlights
import argparse
from nullroute.core import Env
import os
import subprocess

def download_log(remote_host, remote_path, local_path):
    try:
        size = os.stat(local_path).st_size
        rcmd = f"tail -c +{size+1} '{remote_path}'"
    except FileNotFoundError:
        size = 0
        rcmd = f"cat '{remote_path}'"

    with open(local_path, "ab") as fh:
        subprocess.run(["ssh", remote_host, rcmd],
                       stdout=fh,
                       check=True)

    return os.stat(local_path).st_size - size

os.umask(0o077)

cache_path = Env.find_cache_file("highlights.txt")
config_path = Env.find_config_file("irc.conf")

print(f"Cache: {cache_path!r}")
print(f"Config: {config_path!r}")

irc_host = "star"
highlights_file = "irclogs/perl.highmon.log"

delta = download_log(irc_host, highlights_file, cache_path)

if delta == 0:
    print("No new items.")
