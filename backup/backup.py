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
    "--keep-monthly", str(12 * 5), # 5 years
    "--keep-yearly", str(10),
]

#if os.path.exists(local_config_file):
#    res = subprocess.run(["bash", "-c", '. "$conf" && 

def is_older_than(path, age):
    return (time.time() - os.stat(path).st_mtime > age)

def do_borg(*,
            repo=None,
            base=None,
            dirs=None,
            wrap=None,
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

    # This has to be 1 by default, because we might have inherited
    # 'sudo' from borg_$job_wrap.
    need_wd_env = True

    if not wrap and confirm("call borg via systemd-run?"):
        user = os.environ["LOGNAME"]
        ssh_sock = os.environ["SSH_AUTH_SOCK"]
        wrap = [
            # Systemd automatically sets $HOME based on --uid.
            "sudo",
            "systemd-run",
                    #"--quiet",
                    "--pty",
                    f"--description=borg backup task for {user}"
                    f"--uid={user}",
                    f"--setenv=SSH_AUTH_SOCK={ssh_sock}",
                    "--property=AmbientCapabilities=cap_dac_read_search",
                    f"--property=WorkingDirectory={base}",
                    "--collect",
                    "--",
        ]
        need_wd_env = False
    elif not wrap and confirm("call borg via setpriv?"):
        home = os.environ["HOME"]
        gids = ",".join(map(str, os.getgroups()))
        wrap = [
            # Fix $HOME here, *not* in global need_wd_env,
            # because the latter also applies to inherited
            # 'sudo -i' with its deliberate reset-to-root.
            "sudo",
                f"HOME={home}",
            "setpriv",
                f"--reuid={os.getuid()}",
                f"--regid={os.getgid()}",
                f"--groups={gids}",
                "--inh-caps=+dac_read_search",
                "--ambient-caps=+dac_read_search",
                "--",
        ]
        need_wd_env = True
    elif not wrap:
        # No special environment. We always need to chdir, although
        # the envvars are already okay.
        Core.warn("running borg without CAP_DAC_READ_SEARCH")
        need_wd_env = True
    else:
        # We inherited sudo from borg_root_wrap. It deliberately
        # overrides $HOME to /root's, but we still need to chdir
        # and set the SSH socket.
        need_wd_env = True
        # TODO: Maybe move SSH_AUTH_SOCK to here & to setpriv case.

    if need_wd_env:
        wrap += [
            # env --chdir: coreutils v8.28 (debian buster/sid)
            #"env", f"--chdir={base}",
            # nsenter --wd: util-linux v2.23 (debian jessie)
            "nsenter", f"--wd={base}",
            "env", f"SSH_AUTH_SOCK={os.environ['SSH_AUTH_SOCK']}",
        ]

    cmd = [*wrap, "borg", "create", f"{repo}::{tag}", *dirs, *args]
    print(f"Running {cmd!r}")
    #subprocess.run(cmd, check=True)

    if ":" in repo:
        host, _, path = repo.partition(":")
        cmd = [*wrap, "ssh", host, f"grep '^id =' '{repo}/config'"]
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
    #subprocess.run(cmd, check=True)

    #touch(stamp)

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
                wrap=["sudo", "-i"],
                args=[
                    *borg_args,
                    f"--exclude-from={conf}/borg/root_all.exclude",
                    f"--exclude-from={conf}/borg/root_{hostname}.exclude",
                ])
    else:
        Core.die(f"unknown job {job!r}")
