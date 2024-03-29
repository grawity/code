#!/usr/bin/env ruby
# mkca -- tool to generate root CA certificates
# vim: ts=4:sw=4:et
require 'base64'
require 'openssl'
require 'optparse'

class OpenSSL::PKey::EC
    def to_pkcs8_der
        packed_priv = [self.private_key.to_s(16)].pack("H*")
        packed_publ = [self.public_key.to_bn.to_s(16)].pack("H*")
        OpenSSL::ASN1::Sequence([
            OpenSSL::ASN1::Integer(0),
            OpenSSL::ASN1::Sequence([
                OpenSSL::ASN1::ObjectId("1.2.840.10045.2.1"),
                self.public_key.group.to_der,
            ]),
            OpenSSL::ASN1::OctetString(
                OpenSSL::ASN1::Sequence([
                    OpenSSL::ASN1::Integer(1),
                    OpenSSL::ASN1::OctetString(packed_priv),
                    OpenSSL::ASN1::BitString(packed_publ, 1, :EXPLICIT),
                ]).to_der,
            ),
        ]).to_der
    end
end

class OpenSSL::PKey::RSA
    def to_pkcs8_der
        OpenSSL::ASN1::Sequence([
            OpenSSL::ASN1::Integer(0),
            OpenSSL::ASN1::Sequence([
                OpenSSL::ASN1::ObjectId("1.2.840.113549.1.1.1"),
                OpenSSL::ASN1::Null(nil),
            ]),
            OpenSSL::ASN1::OctetString(self.to_der),
        ]).to_der
    end
end

class OpenSSL::PKey::PKey
    def to_pkcs8_pem
        "-----BEGIN PRIVATE KEY-----\n" +
        Base64.encode64(self.to_pkcs8_der) +
        "-----END PRIVATE KEY-----\n"
    end
end

def generate_serial
    # The serial number must be <= 20 bytes (including the '00' padding if the
    # high bit is set, to avoid it being interpreted as negative).
    OpenSSL::BN.new(OpenSSL::Random.random_bytes(8).unpack("H*").first, 16)
end

def generate_key(key_type)
    case key_type
        when /^rsa(\d+)$/
            bits = $1.to_i
            if bits != 2048 && bits != 4096
                raise "RSA keys must be 2048 or 4096 bits"
            end
            return OpenSSL::PKey::RSA.generate(bits)
        when "rsa"
            return OpenSSL::PKey::RSA.generate(2048)
        when "ecp256"
            return OpenSSL::PKey::EC.generate("prime256v1")
        when "ecp384"
            return OpenSSL::PKey::EC.generate("secp384r1")
        when "ecp521"
            return OpenSSL::PKey::EC.generate("secp521r1")
        else
            raise "Unknown private key algorithm #{key_type.inspect}"
    end
end

def create_certificate(subject, days, priv_key)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = generate_serial()
    cert.subject = OpenSSL::X509::Name.parse_rfc2253(subject)
    cert.issuer = cert.subject
    cert.not_before = Time.now
    cert.not_after = cert.not_before + (days * 86400)
    cert.public_key = priv_key

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert

    # keyUsage must be critical (PKIX says that it isn't enforced if not marked
    # critical). Per CA/B, it needs to include 'digitalSignature' if the CA
    # directly signs OCSP responses; approximately 30% of all CAs seem to
    # enable this usage.

    cert.add_extension(ef.create_ext("basicConstraints", "CA:TRUE", true))
    cert.add_extension(ef.create_ext("keyUsage", "keyCertSign, cRLSign", true))
    cert.add_extension(ef.create_ext("subjectKeyIdentifier", "hash"))

    cert.sign(priv_key, OpenSSL::Digest::SHA256.new)

    return cert
end

def parse_lifetime(string)
    case string
        when /^(\d+)y$/
            return ($1.to_i * 365.25).to_i
        when /^(\d+)d?$/
            return $1.to_i
        else
            raise "Invalid lifetime #{string.inspect}"
    end
end

subject = "CN=Foo"
lifetime = "15d"
key_type = "ecp256"
out_cert = nil
out_pkey = nil
overwrite = false

parser = OptionParser.new do |opts|
    opts.on("-s", "--subject DN", String, "Subject DN") do |s|
        subject = s
    end
    opts.on("-l", "--lifetime DAYS", String, "Certificate lifetime") do |s|
        lifetime = s
    end
    opts.on("-a", "--key-type ALG", String, "Private key algorithm") do |s|
        key_type = s
    end
    opts.on("-o", "--out-cert PATH", String, "Certificate output path") do |s|
        out_cert = s
    end
    opts.on("-O", "--out-key PATH", String, "Private key output path") do |s|
        out_pkey = s
    end
    opts.on("-y", "--force", "Overwrite existing output files") do
        overwrite = true
    end
end
parser.parse!

days = parse_lifetime(lifetime)

priv_key = generate_key(key_type)

cert = create_certificate(subject, days, priv_key)

if out_cert
    File.open(out_cert, overwrite ? "w" : "wx", 0o644) do |f|
        f.puts cert
    end
else
    puts cert
end

if out_pkey
    File.open(out_pkey, overwrite ? "w" : "wx", 0o600) do |f|
        f.puts priv_key.to_pkcs8_pem
    end
else
    puts priv_key.to_pkcs8_pem
end
