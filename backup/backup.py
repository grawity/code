#!/usr/bin/env python
import os
import subprocess
import sys
from pprint import pprint
from socket import gethostname

filter_dir = os.path.expanduser("~/Dropbox/Apps/.config/rsync-filters")

def run_task(task_name):
    data = {
        "env": os.environ,
        "hostname": gethostname(),
        "bvol": "/mnt/backup",
    }

    if "@" in task_name:
        v = task_name.split("@", 1)
        task_name = v[0] + "@"
        data["task"] = v[0]
        data["arg"] = v[1]
    else:
        data["task"] = task_name

    task = rsync_tasks[task_name]
    args = []

    if task.get("sudo"):
        args += ["sudo"]

    args += [
        "rsync",
        "-a", "-H", "-A", "-X", "-v", "-z", "-h",
        "--info=progress2",
        "--delete-after",
        "--delete-excluded",
    ]

    src = os.path.expanduser(task["src"]).format(**data)
    dst = os.path.expanduser(task["dst"]).format(**data)
    args += [src, dst]

    dst_parent = os.path.dirname(dst)
    if not os.path.exists(dst_parent):
        print("error: %s not found" % dst_parent)
        return 1

    if "merge" in task:
        for name in task["merge"]:
            path = os.path.join(filter_dir, name.format(**data))
            if os.path.exists(path):
                args += ["-f", "merge %s" % path]

    if "filter" in task:
        for arg in task["filter"]:
            args += ["-f", filter]

    if "args" in task:
        args += task["args"]

    pprint(args)
    subprocess.run(args)

rsync_tasks = {
    "dropbox-push-hd": {
        "src": "~/Dropbox/",
        "dst": "{bvol}/Backup/Dropbox/",
    },

    "home-push-hd": {
        "sudo": True,
        "src": "~/",
        "dst": "{bvol}/Homes/{hostname}/",
        "merge": [
            "home_all",
            "home_{hostname}",
        ],
    },

    "root-push-hd": {
        "sudo": True,
        "src": "/",
        "dst": "{bvol}/Roots/{hostname}/",
        "merge": [
            "root_all",
            "root_{hostname}"
        ],
    },

    "@": {
        "src": "{arg}:",
        "dst": "~/Backup/Homes/{arg}/",
        "merge": [
            "server_home_all",
            "server_home_{arg}",
        ],
        "args": ["-F", "-x", "-P"],
    },

    "root@": {
        "src": "root@{arg}:/",
        "dst": "~/Backup/Roots/{arg}/",
        "merge": [
            "server_root_all",
            "server_root_extra",
            "server_root_{arg}",
        ],
        "args": ["-F", "-x", "-P", "--fake-super"],
    },

    "fs1": {
        "src": "ukradius:pub/{task}/",
        "dst": "{bvol}/Backup/{task}/",
        "filter": [
            "exclude /mirrors/rain",
        ],
    },
}

args = sys.argv[1:]

for task in args:
    run_task(task)
