import subprocess

def get_netrc(machine, login=None):
    cmd = ["getnetrc", "-d", "-n", "-f", "%m\n%l\n%p\n%a", machine]
    if login is not None:
        cmd.append(login)

    try:
        r = subprocess.check_output(cmd)
    except subprocess.CalledProcessError:
        raise KeyError("~/.netrc lookup for %r failed" % machine)

    keys = ["machine", "login", "password", "account"]
    vals = r.decode("utf-8").split("\n")
    if len(keys) != len(vals):
        raise IOError("'getnetrc' returned incorrect data %r" % r)

    return dict(zip(keys, vals))
