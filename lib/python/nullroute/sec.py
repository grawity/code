import subprocess

def get_netrc(machine, login=None):
    cmd = ["getnetrc", "-d", "-n", "-f", "%l\n%p", machine]
    if login is not None:
        cmd.append(login)
    r = subprocess.check_output(cmd)
    return r.decode("utf-8").split("\n")
