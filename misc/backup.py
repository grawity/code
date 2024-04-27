#!/usr/bin/env python3
from nullroute.core import Core, Env
from nullroute.ui import confirm
import argparse
import logging
import os
import subprocess
import sys
import tempfile
import time
import urllib.parse

def get_host_and_path(repo):
    if "://" in repo:
        _, host, path, *_ = urllib.parse.urlparse(repo)
        return host, path
    elif ":" in repo:
        host, _, path = repo.partition(":")
        return host, path
    else:
        return None, repo

def add_user_to_host(repo, user):
    if "://" in repo:
        url = urllib.parse.urlparse(repo)
        if "@" not in url.netloc:
            repo = urllib.parse.urlunsplit([url.scheme,
                                            user + "@" + url.netloc,
                                            url.path,
                                            url.query,
                                            url.fragment])
    elif ":" in repo:
        host, _, path = repo.partition(":")
        if "@" not in host:
            repo = user + "@" + host + ":" + path
    return repo

os.environ["BORG_RELOCATED_REPO_ACCESS_IS_OK"] = "yes"
os.environ["BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK"] = "yes"

hostname = os.uname().nodename

conf = os.path.join(Env.xdg_config_home(),
                    "nullroute.eu.org",
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

def mtime_is_within(path, age):
    try:
        return abs(time.time() - os.stat(path).st_mtime) <= age
    except FileNotFoundError:
        return False

def touch(path):
    with open(path, "a") as fh:
        os.utime(fh.fileno(), None)

def do_borg(*,
            repo=None,
            base=None,
            dirs=None,
            sudo=False,
            excl=None,
            args=None):

    tag = hostname + "." + time.strftime("%Y%m%d.%H%M")

    excl = excl or []
    args = args or []

    # Collect all exclude files, both so that it would not be an error to
    # specify paths of nonexistent host-specific files, and so that 'backup
    # root' would be able to access them in case ~/Dropbox is on NFS.
    excludefile = tempfile.NamedTemporaryFile()
    for x in excl:
        try:
            print(f"backup: using exclude file {x}")
            with open(x, "rb") as fh:
                excludefile.file.write(b"# Begin %s\n" % x.encode())
                for line in fh:
                    excludefile.file.write(line)
                excludefile.file.write(b"\n")
        except FileNotFoundError:
            print(f"backup: {epath} is missing, ignored", file=sys.stderr)
    excludefile.file.flush()
    args += [f"--exclude-from={excludefile.name}"]

    # Prepare the environment for 'borg create'
    user = os.environ["LOGNAME"]
    wrap = ["sudo",
            "systemd-run",
            "--pty",
            "--quiet",
            "--collect"]
    wrap += [f"--setenv={e}={os.environ[e]}"
             for e in ["KRB5CCNAME",
                       "SSH_AUTH_SOCK"]
             if e in os.environ]
    if sudo:
        wrap += [f"--description=borg backup task for {user}/root",
                 f"--property=WorkingDirectory={base}",
                 "--"]
    else:
        # Systemd automatically sets $HOME based on --uid.
        wrap += [f"--description=borg backup task for {user}",
                 f"--property=WorkingDirectory={base}",
                 f"--property=AmbientCapabilities=cap_dac_read_search",
                 f"--uid={user}",
                 "--"]

    # If we'll be running as root and using SSH, default to including the
    # non-root username for SSH.
    if sudo and ":" in repo:
        repo = add_user_to_host(repo, user)
        Core.debug(f"Rewrote repository to {repo!r}")

    cmd = [*wrap, "borg", "create", f"{repo}::{tag}", *dirs, *args]
    Core.debug(f"Running {cmd!r}")
    subprocess.run(cmd, check=True)

    if ":" in repo:
        host, path = get_host_and_path(repo)
        cmd = [*wrap, "ssh", host, f"grep '^id =' '{path}/config'"]
    else:
        cmd = [*wrap, "sh", "-c", f"grep '^id =' '{repo}/config'"]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, check=True)
    repo_id = res.stdout.decode().split()[2]
    stamp = os.path.join(Env.xdg_cache_home(),
                         "nullroute.eu.org",
                         "backup",
                         f"borg_{repo_id}.prune.stamp")

    if mtime_is_within(stamp, 30*86400):
        return

    cmd = [*wrap, "borg", "prune", repo, "--verbose", *borg_keep]
    Core.info("Pruning old snapshots")
    Core.debug(f"Running {cmd!r}")
    subprocess.run(cmd, check=True)

    cmd = [*wrap, "borg", "compact", repo, "--progress"]
    Core.info("Compacting repository")
    Core.debug(f"Running {cmd!r}")
    subprocess.run(cmd, check=True)

    touch(stamp)

parser = argparse.ArgumentParser()
parser.add_argument("--borg-repo")
parser.add_argument("-v", "--verbose", action="store_true")
parser.add_argument("job", nargs="*")
args = parser.parse_args()

Core.set_log_level([Core.LOG_INFO, Core.LOG_DEBUG][args.verbose])
logging.basicConfig(level=[logging.INFO, logging.DEBUG][args.verbose],
                    format="%(message)s")

for job in args.job:
    try:
        if job == "home":
            do_borg(repo=args.borg_repo or borg_home_repo,
                    base="~",
                    dirs=["."],
                    excl=[
                        f"{conf}/borg/home_all.exclude",
                        f"{conf}/borg/home_{hostname}.exclude",
                    ])
        elif job == "root":
            do_borg(repo=args.borg_repo or borg_root_repo,
                    base="/",
                    dirs=["/"],
                    sudo=True,
                    excl=[
                        f"{conf}/borg/root_all.exclude",
                        f"{conf}/borg/root_{hostname}.exclude",
                    ])
        else:
            exit(f"error: Unknown job {job!r}")
    except subprocess.CalledProcessError as e:
        exit(f"error: {e.cmd[0]!r} exited with {e.returncode}")
