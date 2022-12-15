#!/usr/bin/env python3
# mkca -- tool to generate root CA certificates
import argparse
import certbuilder
from datetime import datetime, timedelta, timezone
import os
import oscrypto.asymmetric
import secrets
import sys

def generate_serial():
    # The serial number must be <= 20 bytes (including the '00' padding if the
    # high bit is set, to avoid it being interpreted as negative).
    return secrets.randbits(128)

def create_certificate(subject_cn, subject_o, days, *, key_type="ecp256"):
    """
    Create a self-signed CA certificate; return both the certificate and
    private key as ASCII PEM strings.
    """

    subj = {"common_name": subject_cn}
    if subject_o:
        subj |= {"organization_name": subject_o}

    if key_type in {"ec", "ecp256"}:
        (pub, priv) = oscrypto.asymmetric.generate_pair("ec", curve="secp256r1")
    elif key_type in {"rsa", "rsa2048"}:
        (pub, priv) = oscrypto.asymmetric.generate_pair("rsa", bit_size=2048)
    else:
        raise ValueError(f"Bad algorithm {key_type!r}")

    cb = certbuilder.CertificateBuilder(subj, pub)
    cb.self_signed = True
    cb.serial_number = generate_serial()
    cb.end_date = datetime.now().astimezone(timezone.utc) + timedelta(days=days)
    cb.ca = True
    # Override the key_usage set by 'ca = True' to include digital_signature,
    # as many new CAs also do.
    cb.key_usage = {"digital_signature", "key_cert_sign", "crl_sign"}
    cert = cb.build(priv)

    pem_cert = oscrypto.asymmetric.dump_certificate(cert, "pem").decode()
    pem_priv = oscrypto.asymmetric.dump_private_key(priv, None).decode()
    return pem_cert, pem_priv

def parse_lifetime(string):
    if string[-1] == "y":
        return int(int(string[:-1]) * 365.25)
    elif string[-1] == "d":
        return int(string[:-1])
    else:
        return int(string)

parser = argparse.ArgumentParser()
parser.add_argument("-c", "--common-name", "--cn",
                    required=True,
                    help="Subject common name (CN)")
parser.add_argument("-g", "--organization",
                    help="Subject organization (O)")
parser.add_argument("-l", "--lifetime",
                    default="1d",
                    help="Certificate lifetime in days")
parser.add_argument("-a", "--key-type",
                    default="ecp256",
                    help="Private key algorithm")
parser.add_argument("-o", "--out-cert",
                    help="Certificate output path")
parser.add_argument("-O", "--out-key",
                    help="Private key output path")
args = parser.parse_args()

try:
    days = parse_lifetime(args.lifetime)
except ValueError as e:
    exit(f"error: Invalid lifetime {args.lifetime!r}")

cert, priv = create_certificate(subject_cn=args.common_name,
                                subject_o=args.organization,
                                days=days,
                                key_type=args.key_type)

if args.out_cert:
    cert_fh = open(args.out_cert, "w")
else:
    cert_fh = sys.stdout

if args.out_key:
    priv_fh = open(args.out_key, "w")
    os.chmod(priv_fh.fileno(), 0o600)
else:
    priv_fh = sys.stdout

cert_fh.write(cert)
cert_fh.flush()

priv_fh.write(priv)
priv_fh.flush()
