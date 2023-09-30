#!/usr/bin/env python3
from collections import defaultdict
import logging
import os

def tabdump():
    fields = None
    for line in os.popen("sudo kdb5_util tabdump keyinfo", "r"):
        values = line.rstrip("\n").split("\t")
        if not fields:
            fields = values
        else:
            yield dict(zip(fields, values))

def join(items):
    return ", ".join(sorted(items))

logging.basicConfig(level=logging.DEBUG,
                    format="%(levelname)s: %(message)s")

by_princ = defaultdict(set)

for x in tabdump():
    name = x["name"]
    kvno = int(x["kvno"])
    etype = x["enctype"]
    by_princ[name].add(etype)

GOOD_TYPES = {
    "aes256-cts-hmac-sha1-96",
    "aes128-cts-hmac-sha1-96",
    #"aes128-cts-hmac-sha256-128",
    #"aes256-cts-hmac-sha384-192",
}
OBS_ETYPES = {
    "des3-cbc-sha1",
    "arcfour-hmac",
}
BAD_ETYPES = {
    "des-cbc-crc",
    "des-cbc-md4",
    "des-cbc-md5",
    "arcfour-hmac-exp",
}

for name, etypes in by_princ.items():
    # Skip if exact match for modern enctype list
    if etypes == GOOD_TYPES:
        continue

    # Skip special single-key principals if they have any good key
    if name.startswith(("K/M@", "kadmin/history@")) and etypes & GOOD_TYPES:
        continue

    if not (GOOD_TYPES & etypes):
        logging.warn("'\033[1m%s\033[m' has no new enctypes: only \033[1m%s\033[m",
                     name, join(etypes))
    elif missing := (GOOD_TYPES - etypes):
        logging.notice("'\033[1m%s\033[m' is missing some new enctypes: has \033[1m%s\033[m, needs \033[1m%s\033[m",
                       name, join(etypes), join(missing))

    if unwanted := (BAD_ETYPES & etypes):
        logging.warn("'\033[1m%s\033[m' has some broken enctypes: \033[1;33m%s\033[m",
                     name, join(unwanted))

    if unwanted := (OBS_ETYPES & etypes):
        logging.info("'%s' has some deprecated enctypes: \033[1m%s\033[m",
                     name, join(unwanted))
