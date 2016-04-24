from hashlib import sha1
import hmac
import struct
import time

def Truncate(hmac_sha1):
    """
    converts an HMAC-SHA-1 value into a HOTP value as in RFC 4226 section 5.2
    <https://tools.ietf.org/html/rfc4226#section-5.3>
    """
    offset = int(hmac_sha1[-1], 16)
    binary = int(hmac_sha1[(offset * 2):((offset * 2) + 8)], 16) & 0x7fffffff
    return str(binary)

def HOTP(K, C, digits=6):
    C_bytes = struct.pack(b"!Q", C)
    hmac_sha1 = hmac.new(key=K, msg=C_bytes, digestmod=sha1).hexdigest()
    return Truncate(hmac_sha1)[-digits:]

def TOTP(K, digits=6, window=30):
    C = int(time.time() / window)
    return HOTP(K, C, digits=digits)
