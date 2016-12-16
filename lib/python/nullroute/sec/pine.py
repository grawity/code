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
        char -= key
        if char < FIRSTCH - TABSZ:
            char += 2 * TABSZ
        elif char < FIRSTCH:
            char += TABSZ
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
