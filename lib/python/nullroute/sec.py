import subprocess

def save_libsecret(label, secret, attributes):
    cmd = ["secret-tool", "store", "--label=%s" % label]
    for k, v in attributes.items():
        cmd += [str(k), str(v)]

    if hasattr(secret, "encode"):
        secret = secret.encode("utf-8")

    with subprocess.Popen(cmd, stdin=subprocess.PIPE) as proc:
        out, err = proc.communicate(secret)
        ret = proc.wait()
        if ret != 0:
            raise IOError("libsecret store failed: (%r, %r)" % (ret, err))

def get_libsecret(attributes):
    cmd = ["secret-tool", "lookup"]
    for k, v in attributes.items():
        cmd += [str(k), str(v)]

    try:
        r = subprocess.check_output(cmd)
    except subprocess.CalledProcessError:
        raise KeyError("libsecret lookup failed")
    else:
        return r

def clear_libsecret(attributes):
    cmd = ["secret-tool", "clear"]
    for k, v in attributes.items():
        cmd += [str(k), str(v)]

    try:
        subprocess.check_output(cmd)
    except subprocess.CalledProcessError:
        raise KeyError("libsecret clear failed")

def get_netrc(machine, login=None, service=None):
    if service:
        machine = "%s/%s" % (service, machine)
    cmd = ["getnetrc", "-d", "-n", "-f", "%m\n%l\n%p\n%a", machine]
    if login:
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

def get_netrc_service(machine, service, **kw):
    return get_netrc("%s/%s" % (service, machine), **kw)
