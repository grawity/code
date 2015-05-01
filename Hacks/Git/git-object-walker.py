#!/usr/bin/env python
from collections import deque
import sys
import subprocess
import requests
import binascii

def status(msg):
    sys.stdout.write(msg)
    sys.stdout.flush()

def store_object(obj_type, obj_data):
    cmd = ['git', 'hash-object', '-w', '-t', obj_type, '--stdin']
    with subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE) as proc:
        if obj_type == 'tree':
            for f_mode, _, f_hash, f_name in parse_tree(obj_data):
                buf = b""
                buf += f_mode.lstrip("0").encode("utf-8")
                buf += b" "
                buf += f_name.encode("utf-8")
                buf += b"\0"
                buf += binascii.unhexlify(f_hash)
                proc.stdin.write(buf)
        else:
            proc.stdin.write(obj_data)
        proc.stdin.close()
        obj_hash = proc.stdout.readline().decode('utf-8').rstrip('\n')
    status("stored %s\n" % obj_hash)
    return obj_hash

def parse_kv(data):
    in_header = True
    key = ""
    val = ""
    for line in data.decode("utf-8").splitlines():
        line += "\n"
        if in_header:
            if line == "\n":
                in_header = False
                if len(val):
                    yield key, val.rstrip("\n")
                key, val = None, ""
            elif line[0] == " ":
                val += line[1:]
            else:
                if len(val):
                    yield key, val.rstrip("\n")
                key, val = line.split(" ", 1)
        else:
            val += line
    yield key, val.rstrip("\n")

def parse_tree(data):
    for line in data.decode("utf-8").splitlines():
        yield line.split(None, 3)

def parse_object(obj_type, obj_data):
    if obj_type == 'commit':
        for key, val in parse_kv(obj_data):
            if key in {'tree', 'parent'}:
                yield val
    elif obj_type == 'tag':
        for key, val in parse_kv(obj_data):
            if key == 'object':
                yield val
    elif obj_type == 'tree':
        for _, f_type, f_hash, _ in parse_tree(obj_data):
            if f_type != 'commit':
                yield f_hash
    else:
        return

def set_ref(name, obj_hash):
    subprocess.call(['git', 'update-ref', name, obj_hash])

pending = deque()
seen = set()

pending.append('HEAD')

while len(pending) > 0:
    obj = pending.popleft()
    if obj in seen:
        status("seen:  %s\n" % obj)
    else:
        status("fetch: %s..." % obj)
        r = requests.get("http://nullroute.eu.org/:%s" % obj)
        if r.status_code == 200:
            obj_hash = r.headers['git-object-hash']
            obj_type = r.headers['git-object-type']
            obj_size = int(r.headers['git-object-size'])
            obj_data = r.content
            status("ok, got %s {%d}\n" % (obj_type, obj_size))
            new_hash = store_object(obj_type, obj_data)
            if new_hash == obj_hash:
                seen.add(new_hash)
            else:
                status("!! mismatch: %s → %s" % (obj_hash, new_hash))
            if obj_type in {'commit', 'tag', 'tree'}:
                ref_objects = parse_object(obj_type, obj_data)
                pending.extend(ref_objects)
            if obj == "HEAD":
                set_ref(obj, new_hash)
        else:
            status("err %d, %r\n" % (r.status_code, r.headers))
