import subprocess

def save_libsecret(label, secret, attributes):
    cmd = ["secret-tool", "store", "--label=%s" % label]
    for k, v in attributes.items():
        cmd += [str(k), str(v)]

    if hasattr(secret, "encode"):
        secret = secret.encode("utf-8")

    r = subprocess.run(cmd, input=secret,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    if r.returncode != 0:
        raise IOError("libsecret store failed: (%r, %r)" % (r.returncode,
                                                            r.stderr.decode()))

def get_libsecret(attributes):
    cmd = ["secret-tool", "lookup"]
    for k, v in attributes.items():
        cmd += [str(k), str(v)]

    r = subprocess.run(cmd, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    if r.returncode != 0:
        raise KeyError("libsecret lookup failed: %r" % r.stderr.decode())

    return r.stdout

def clear_libsecret(attributes):
    cmd = ["secret-tool", "clear"]
    for k, v in attributes.items():
        cmd += [str(k), str(v)]

    r = subprocess.run(cmd, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    if r.returncode != 0:
        raise KeyError("libsecret clear failed: %r" % r.stderr.decode())

def get_netrc(machine, login=None, service=None):
    if service:
        machine = "%s/%s" % (service, machine)

    cmd = ["getnetrc", "-d", "-n", "-f", "%m\n%l\n%p\n%a", machine]
    if login:
        cmd.append(login)

    r = subprocess.run(cmd, stdout=subprocess.PIPE)
    if r.returncode != 0:
        raise KeyError("~/.netrc lookup for %r failed" % machine)

    keys = ["machine", "login", "password", "account"]
    vals = r.stdout.decode("utf-8").split("\n")
    if len(keys) != len(vals):
        raise IOError("'getnetrc' returned weird data %r" % r)

    return dict(zip(keys, vals))

def get_netrc_service(machine, service, **kw):
    return get_netrc("%s/%s" % (service, machine), **kw)
