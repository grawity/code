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

generate = true
key_type = "ecp256"
bits = 2048

subject = "CN=Foo"
lifetime = "15d"
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

begin
    days = parse_lifetime(lifetime)
rescue => e
    warn "error: #{e}"
    exit 1
end

if generate
    case key_type
    when "rsa"
        priv_key = OpenSSL::PKey::RSA.new(bits)
    when "ecp256"
        priv_key = OpenSSL::PKey::EC.new("prime256v1").generate_key
    when "ecp384"
        priv_key = OpenSSL::PKey::EC.new("secp384r1").generate_key
    when "ecp521"
        priv_key = OpenSSL::PKey::EC.new("secp521r1").generate_key
    else
        raise "unknown private key algorithm #{key_type.inspect}"
    end
else
    File.open(pkey_path) do |fh|
        priv_key = OpenSSL::PKey.read(fh)
    end
end

cert = OpenSSL::X509::Certificate.new
cert.version = 2
cert.subject = OpenSSL::X509::Name.parse_rfc2253(subject)
cert.issuer = cert.subject
cert.not_before = Time.now
cert.not_after = cert.not_before + (days * 86400)
cert.public_key = priv_key

ef = OpenSSL::X509::ExtensionFactory.new
ef.subject_certificate = cert
ef.issuer_certificate = cert
cert.extensions << ef.create_extension("basicConstraints", "CA:TRUE", true)

cert.sign(priv_key, OpenSSL::Digest::SHA256.new)

if out_cert
    File.open(out_cert, overwrite ? "w" : "wx", 0o644) do |f|
        f.puts cert
    end
else
    puts cert
end

if generate
    if out_pkey
        File.open(out_pkey, overwrite ? "w" : "wx", 0o600) do |f|
            f.puts priv_key.to_pkcs8_pem
        end
    else
        puts priv_key.to_pkcs8_pem
    end
end
