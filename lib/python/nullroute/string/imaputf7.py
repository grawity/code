# Originally based on the imap_utf7.py file from imapclient 2.1.0, which is:
# (c) 2014, Menno Smits
# Released under the "New" BSD license <https://spdx.org/licenses/BSD-3-Clause.html>

import binascii

def encode_imap_utf7(s: str) -> bytes:
    def base64_utf7_encode(buffer):
        s = "".join(buffer).encode("utf-16be")
        return binascii.b2a_base64(s).rstrip(b"\n=").replace(b"/", b",")

    res = bytearray()
    b64_buffer = []
    for c in s:
        # printable ascii case should not be modified
        o = ord(c)
        if 0x20 <= o <= 0x7e:
            if b64_buffer:
                res.extend(b'&' + base64_utf7_encode(b64_buffer) + b'-')
                del b64_buffer[:]
            # Special case: & is used as shift character so we need to escape it in ASCII
            if o == 0x26:  # & = 0x26
                res.extend(b'&-')
            else:
                res.append(o)
        # Bufferize characters that will be encoded in base64 and append them later
        # in the result, when iterating over ASCII character or the end of string
        else:
            b64_buffer.append(c)
    # Consume the remaining buffer if the string finish with non-ASCII characters
    if b64_buffer:
        res.extend(b'&' + base64_utf7_encode(b64_buffer) + b'-')
        del b64_buffer[:]
    return bytes(res)

def decode_imap_utf7(s: bytes) -> str:
    def base64_utf7_decode(s):
        s_utf7 = b"+" + s.replace(b",", b"/") + b"-"
        return s_utf7.decode("utf-7")

    res = []
    # Store base64 substring that will be decoded once stepping on end shift character
    b64_buffer = bytearray()
    for c in s:
        # Shift character without anything in buffer -> starts storing base64 substring
        if c == ord(b"&") and not b64_buffer:
            b64_buffer.append(c)
        # End shift char. -> append the decoded buffer to the result and reset it
        elif c == ord(b"-") and b64_buffer:
            # Special case &-, representing "&" escaped
            if len(b64_buffer) == 1:
                res.append("&")
            else:
                res.append(base64_utf7_decode(b64_buffer[1:]))
            b64_buffer = bytearray()
        # Still buffering between the shift character and the shift back to ASCII
        elif b64_buffer:
            b64_buffer.append(c)
        # No buffer initialized yet, should be an ASCII printable char
        else:
            res.append(chr(c))
    # Decode the remaining buffer if any
    if b64_buffer:
        res.append(base64_utf7_decode(b64_buffer[1:]))
    return "".join(res)
