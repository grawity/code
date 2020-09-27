# Originally based on the imap_utf7.py file from imapclient 2.1.0, which is:
# (c) 2014, Menno Smits
# Released under the "New" BSD license <https://spdx.org/licenses/BSD-3-Clause.html>

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
