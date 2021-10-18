def irc_split(buf):
    """
    Split a protocol line into tokens (without decoding or interpreting).
    """
    buf = buf.rstrip(b"\r\n").split(b" ")
    i, n = 0, len(buf)
    parv = []

    # Skip leading whitespace
    while i < n and buf[i] == b"":
        i += 1

    # Get @tags if present
    if i < n and buf[i].startswith(b"@"):
        parv.append(buf[i])
        i += 1
        while i < n and buf[i] == b"":
            i += 1

    # Get :prefix if present
    if i + 1 < n and buf[i].startswith(b":"):
        parv.append(buf[i])
        i += 1
        while i < n and buf[i] == b"":
            i += 1

    # Get parameters until :trailing
    while i < n:
        if buf[i].startswith(b":"):
            break
        elif buf[i] != b"":
            parv.append(buf[i])
        i += 1

    # Get trailing parameter
    if i < n:
        trailing = b" ".join(buf[i:])
        parv.append(trailing[1:])

    return parv

def irc_join(parv):
    """
    Join already-encoded tokens into a protocol line.
    """
    i, n = 0, len(parv)

    if i < n and parv[i].startswith(b"@"):
        if b" " in parv[i]:
            raise ValueError("Parameter %d contains spaces: %r" % (i, parv[i]))
        i += 1
    if i < n and b" " in parv[i]:
        raise ValueError("Parameter %d contains spaces: %r" % (i, parv[i]))
    if i < n and parv[i].startswith(b":"):
        if b" " in parv[i]:
            raise ValueError("Parameter %d contains spaces: %r" % (i, parv[i]))
        i += 1
    while i < n-1:
        if not parv[i]:
            raise ValueError("Parameter %d is empty: %r" % (i, parv[i]))
        elif parv[i].startswith(b":"):
            raise ValueError("Parameter %d starts with colon: %r" % (i, parv[i]))
        elif b" " in parv[i]:
            raise ValueError("Parameter %d contains spaces: %r" % (i, parv[i]))
        i += 1

    buf = parv[:i]
    if i < n:
        if not parv[i] or parv[i].startswith(b":") or b" " in parv[i]:
            buf.append(b":" + parv[i])
        else:
            buf.append(parv[i])

    return b" ".join(buf) + b"\r\n"
