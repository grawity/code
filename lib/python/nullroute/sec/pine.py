import os

FIRSTCH = 0x20
LASTCH = 0x7e
TABSZ = (LASTCH - FIRSTCH + 1)

def _xlate_in(key, char):
    if char >= FIRSTCH and char <= LASTCH:
        key = (key + char - FIRSTCH) % TABSZ
        char = key + FIRSTCH
        return key, char
    else:
        return key, char

def _xlate_out(key, char):
    if char >= FIRSTCH and char <= LASTCH:
        #char -= key
        #if char < FIRSTCH - TABSZ:
        #    char += 2 * TABSZ
        #elif char < FIRSTCH:
        #    char += TABSZ
        char = (char - key + 2*TABSZ)
        while char > LASTCH:
            char -= TABSZ
        key = (key + char - FIRSTCH) % TABSZ
        return key, char
    else:
        return key, char

def decrypt_line(key, line):
    out = ""
    for char in line:
        char = ord(char)
        key, char = _xlate_out(key, char)
        out += chr(char)
    return out

def encrypt_line(key, line):
    out = ""
    for char in line:
        char = ord(char)
        key, char = _xlate_in(key, char)
        out += chr(char)
    return out

def decrypt_file(fh):
    for n, line in enumerate(fh):
        yield decrypt_line(n, line)

class Passfile(object):
    def __init__(self, path=None):
        self.path = path or os.path.expanduser("~/.pine-passfile")
        self._items = []
        self._by_host = {}
        self.modified = False
        self.reload()

    def reload(self):
        with open(self.path, "r") as fh:
            for n, line in enumerate(fh):
                line = decrypt_line(n, line)
                row = line.rstrip("\n").split("\t")
                self._items.append(row)
                self._by_host[row[2], row[1]] = row
        self.modified = False

    def add(self, hostname, login, passwd, secure_only=True):
        row = [passwd, login, hostname, str(int(secure_only))]
        old_row = self._by_host.get((hostname, login))
        if old_row:
            old_row.clear()
            old_row.extend(row)
        else:
            self._items.append(row)
            self._by_host[row[2], row[1]] = row
        self.modified = True

    def get(self, hostname, login, secure_only=True):
        return tuple(self._by_host.get((hostname, login), ()))

    def save(self, force=False):
        if self.modified or force:
            with open(self.path, "w") as fh:
                for n, row in enumerate(self._items):
                    line = encrypt_line(n, "\t".join(row))
                    print(line, file=fh)
            self.modified = False

if __name__ == "__main__":
    from pprint import pprint

    pf = Passfile()

    print("--- Items ---")
    pprint(pf._items)
    print()

    print("--- Lookup table ---")
    pprint(pf._by_host)
    print()
