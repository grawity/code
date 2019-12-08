import math
import re

ALPHABET_BASE36_TS6 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

def int_to_base(num, base, alphabet):
    res = ""
    while num:
        res += alphabet[num % base]
        num //= base
    return res[::-1] or alphabet[0]

def escape_html(text):
    xlat = [
        ('&', '&amp;'),
        ('<', '&lt;'),
        ('>', '&gt;'),
        ('"', '&quot;'),
    ]
    for k, v in xlat:
        text = text.replace(k, v)
    return text

def escape_shell(text):
    escaped = "\\$`\""
    quoted = " \n'?*[]()<>{};&|~" + escaped
    if any(c in text for c in quoted):
        for k in escaped:
            text = text.replace(k, "\\" + k)
        text = '"%s"' % text
    return text

def filter_filename(name, safe=False, allow_space=True, allow_nonbmp=True):
    if safe:
        allow_space = False
        allow_nonbmp = False
    xlat = [
        # space and unsafe
        (' ', '_' if not allow_space else ' '),
        ('"', '_'),
        ('*', '_'),
        ('/', '_' if safe else '⁄'),
        (':', '_' if safe else '∶'),
        ('<', '_' if safe else '‹'),
        ('>', '_' if safe else '›'),
        ('?', '_' if safe else '？'),
        ('|', '_' if safe else '¦'),
        ('\\', '_' if safe else '∖'),   # U+2216 SET MINUS (1.1)
        #('\\', '_' if safe else '⟍'),  # U+27CD MATHEMATICAL FALLING DIAGONAL (6.1)
        #('\\', '_' if safe else '﹨'),  # U+FE68 SMALL REVERSE SOLIDUS (1.1)
        #('\\', '_' if safe else '＼'),  # U+FF3C FULLWIDTH REVERSE SOLIDUS (1.1)
        # wide characters
        ('　', '_' if not allow_space else ' '),
    ]
    name = name.strip()
    for k, v in xlat:
        name = name.replace(k, v)
    if name.startswith("."):
        name = "_" + name
    if name.endswith("~") and not safe:
        name = name.replace("~", "∼")
    # Dropbox cannot sync non-BMP characters
    # https://github.com/dropbox/dropbox-sdk-java/issues/42#issuecomment-195580050
    if not allow_nonbmp:
        name = re.sub(r"[^\u0000-\uFFFF]", "_" if safe else "�", name)
    return name

def fmt_size_short(nbytes, decimals=1, si=False):
    prefixes = "kMGTPEZYH"
    div = 1000 if si else 1024
    if nbytes == 0:
        return "0"
    exp = int(math.log(nbytes, div))
    exp = min(exp, len(prefixes))
    return "%.*f%s" % (decimals, nbytes / div**exp,
                       prefixes[exp-1] if exp else "")

def fmt_size(nbytes, decimals=1, si=False, unit="B", long_unit="bytes"):
    prefixes = "kMGTPEZYH"
    div = 1000 if si else 1024
    if nbytes == 0:
        return "0 %s" % (long_unit or unit)
    exp = int(math.log(nbytes, div))
    exp = min(exp, len(prefixes))
    if exp == 0:
        return "%.*f %s" % (decimals, nbytes,
                            long_unit or unit)
    else:
        return "%.*f %s%s" % (decimals, nbytes / div**exp,
                             prefixes[exp-1] if exp else "", unit)

def unescape(line, errors="surrogateescape"):
    """
    Undo \000 octal and \xAB hexadecimal escapes
    Undo \" and \\ to literals
    """
    state = 0
    acc = ""
    outv = [""]
    esc = {"n": "\n", "t": "\t"}
    for ch in line:
        if state == 1:
            if ch in "01234567" and len(acc) < 3:
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
    # outv may contain pieces of str
    for cur in outv:
        if hasattr(cur, "encode"):
            outb += cur.encode("utf-8")
        else:
            outb.append(cur)
    return outb.decode("utf-8", errors=errors)

def unquote(line, **kwargs):
    if line[0] == line[-1] == "\"":
        line = line[1:-1]
    return unescape(line, **kwargs)

def fmt_duration(secs):
    y = abs(secs)

    y, s = divmod(y, 60)
    y, m = divmod(y, 60)
    y, h = divmod(y, 24)
    y, d = divmod(y, 365)

    if y > 0:       return "%dy %dd" % (y, d)
    elif d > 14:    return "%dd" % (d,)
    elif d > 0:     return "%dd %dh" % (d, h)
    elif h > 0:     return "%dh %dm" % (h, m)
    elif m > 9:     return "%dm" % (m,)
    elif m > 0:     return "%dm %ds" % (m, s)
    else:           return "%ds" % (s,)

def parse_duration(arg):
    import re
    pat = r"""
        ^
        \s* (?: (?P<y> -? \d+ ) y )?
        \s* (?: (?P<w> -? \d+ ) w )?
        \s* (?: (?P<d> -? \d+ ) d )?
        \s* (?: (?P<h> -? \d+ ) h )?
        \s* (?: (?P<m> -? \d+ ) m )?
        \s* (?: (?P<s> -? \d+ ) s? )?
        $
    """
    t = 0
    m = re.match(pat, arg, re.X)
    if m:
        m = m.groupdict()
        if m["y"]: t += int(m["y"]) * 60*60*24*365
        if m["w"]: t += int(m["w"]) * 60*60*24*7
        if m["d"]: t += int(m["d"]) * 60*60*24
        if m["h"]: t += int(m["h"]) * 60*60
        if m["m"]: t += int(m["m"]) * 60
        if m["s"]: t += int(m["s"])
    else:
        raise ValueError("malformed duration %r" % arg)
    return t

class ObjectDict(dict):
    def __getattr__(self, attr):
        try:
            return self[attr]
        except KeyError:
            raise AttributeError("%r object has no attribute %r" \
                                 % (self.__class__.__name__, attr))

    def __setattr__(self, attr, value):
        self[attr] = value
