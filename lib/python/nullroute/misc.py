import math

def filter_filename(name):
    xlat = [
        (' ', '_'),
        ('　', '_'),
        ('"', '_'),
        ('*', '_'),
        ('/', '⁄'),
        (':', '_'),
        ('<', '_'),
        ('>', '_'),
        ('?', '？'),
    ]
    name = name.strip()
    for k, v in xlat:
        name = name.replace(k, v)
    if name.startswith("."):
        name = "·" + name[1:]
    return name

def uniq(items):
    seen = set()
    for item in items:
        if item not in seen:
            seen.add(item)
            yield item

def fmt_size_foo(n, d=1, u=1024):
    cs = "BkMGTPEZYH"
    e = 0
    while n >= u:
        n /= u
        e += 1
    c = cs[e]
    return "%.*f%s" % (d, n, c)

def fmt_size(nbytes, si=False):
    if nbytes == 0:
        return "zero bytes"
    prefixes = ".kMGTPEZYH"
    div = 1000 if si else 1024
    exp = int(math.log(nbytes, div))
    if exp == 0:
        return "%.1f bytes" % nbytes
    elif exp < len(prefixes):
        quot = nbytes / div**exp
        return "%.1f %sB" % (quot, prefixes[exp])
    else:
        exp = len(prefixes) - 1
        quot = nbytes / div**exp
        return "%f %sB" % (quot, prefixes[exp])
    return str(nbytes)

def unescape(line):
    state = 0
    acc = ""
    outv = [""]
    esc = {"n": "\n", "t": "\t"}
    for ch in line:
        if state == 1:
            if ch in "01234567" and len(acc) < 4:
                acc += ch
            elif len(acc) > 0:
                outv.append(int(acc, 8))
                outv.append("")
                state = 0
                # fall
            # TODO: hex
            else:
                outv[-1] += esc.get(ch, ch)
                state = 0
                continue
        if state == 0:
            if ch == "\\":
                state = 1
                acc = ""
            elif ch == "\"":
                pass
            else:
                outv[-1] += ch
    outb = bytearray()
    for cur in outv:
        if hasattr(cur, "encode"):
            outb += cur.encode("utf-8")
        else:
            outb.append(cur)
    return outb.decode("utf-8")

def unquote(line):
    if line[0] == line[-1] == "\"":
        line = line[1:-1]
    return unescape(line)
