import subprocess

def get_netrc(machine, login=None):
    cmd = ["getnetrc", "-d", "-n", "-f", "%m\n%l\n%p\n%a", machine]
    if login is not None:
        cmd.append(login)
    r = subprocess.check_output(cmd)
    keys = ["machine", "login", "password", "account"]
    vals = r.decode("utf-8").split("\n")
    return dict(zip(keys, vals))
