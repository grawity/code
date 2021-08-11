#!/usr/bin/env python3
from nullroute.core import Core, Env
from nullroute.ui import confirm
import argparse
import os
import subprocess
import time

hostname = os.uname().nodename

conf = os.path.join(Env.xdg_config_home(),
                    Env.vendor,
                    "synced")

local_config_file = Env.find_config_file("backup.conf.sh")

borg_root_repo = f"/vol4/Backup/Roots/{hostname}.borg"
borg_home_repo = f"/vol4/Backup/Homes/{hostname}.borg"
borg_args = [
    "--progress",
    "--stats",
    "--one-file-system",
    "--exclude-caches",
    "--exclude-if-present=.nobackup",
    "--keep-exclude-tags",
]
borg_keep = [
    "--keep-daily", str(7),
    "--keep-weekly", str(8),
    "--keep-monthly", str(12 * 3), # 3 years
    "--keep-yearly", str(10),
]

#if os.path.exists(local_config_file):
#    res = subprocess.run(["bash", "-c", '. "$conf" && 

def is_older_than(path, age):
    return (time.time() - os.stat(path).st_mtime > age)

def touch(path):
    open(path, "r+").close()

def do_borg(*,
            repo=None,
            base=None,
            dirs=None,
            sudo=False,
            args=None):

    tag = hostname + "." + time.strftime("%Y%m%d.%H%M")

    # idiot-proofing: if nonexistent exclude files were specified, create them
    next = -1
    for arg in args:
        if arg.startswith("--exclude-from="):
            _, _, arg = arg.partition("=")
            next = 1
        elif arg == "--exclude-from":
            next = 0

        if next == 0 and not os.path.exists(arg):
            Core.notice(f"creating missing exclude file {arg!r}")
            touch(arg)

        if next >= 0:
            next -= 1

    # run borg create

    user = os.environ["LOGNAME"]
    wrap = ["sudo",
            "systemd-run",
            "--pty",
            "--collect"]
    if sudo:
        wrap += [f"--description=borg backup task for {user}/root",
                 f"--property=WorkingDirectory={base}",
                 "--"]
    else:
        # Systemd automatically sets $HOME based on --uid.
        setenv = [f"--setenv={e}={v}"
                  for e in ["KRB5CCNAME", "SSH_AUTH_SOCK"]
                  if (v := os.environ.get(e))]
        wrap += [f"--description=borg backup task for {user}",
                 f"--property=WorkingDirectory={base}",
                 f"--property=AmbientCapabilities=cap_dac_read_search",
                 f"--uid={user}",
                 *setenv,
                 "--"]

    cmd = [*wrap, "borg", "create", f"{repo}::{tag}", *dirs, *args]
    print(f"Running {cmd!r}")
    subprocess.run(cmd, check=True)

    if ":" in repo:
        host, _, path = repo.partition(":")
        cmd = [*wrap, "ssh", host, f"grep '^id =' '{path}/config'"]
    else:
        cmd = [*wrap, "sh", "-c", f"grep '^id =' '{repo}/config'"]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, check=True)
    repo_id = res.stdout.decode().split()[2]
    stamp = os.path.join(Env.xdg_cache_home(),
                         Env.vendor,
                         "backup",
                         f"borg_{repo_id}.prune.stamp")

    if not is_older_than(stamp, 30*86400):
        return

    cmd = [*wrap, "borg", "prune", repo, "--verbose", *borg_keep]
    print(f"Running {cmd!r}")
    subprocess.run(cmd, check=True)

    touch(stamp)

parser = argparse.ArgumentParser()
parser.add_argument("--borg-repo")
parser.add_argument("job", nargs="*")
args = parser.parse_args()

for job in args.job:
    if job == "home":
        do_borg(repo=args.borg_repo or borg_home_repo,
                base="~",
                dirs=["."],
                args=[
                    *borg_args,
                    f"--exclude-from={conf}/borg/home_all.exclude",
                    f"--exclude-from={conf}/borg/home_{hostname}.exclude",
                ])
    elif job == "root":
        do_borg(repo=args.borg_repo or borg_root_repo,
                base="/",
                dirs=["/"],
                sudo=True,
                args=[
                    *borg_args,
                    f"--exclude-from={conf}/borg/root_all.exclude",
                    f"--exclude-from={conf}/borg/root_{hostname}.exclude",
                ])
    else:
        Core.die(f"unknown job {job!r}")
