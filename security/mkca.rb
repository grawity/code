#!/usr/bin/env ruby
require 'base64'
require 'openssl'
require 'optparse'

class OpenSSL::PKey::PKey
    def to_pkcs8_pem
        "-----BEGIN PRIVATE KEY-----\n" +
        Base64.encode64(self.to_pkcs8_der) +
        "-----END PRIVATE KEY-----\n"
    end
end

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

generate = true
key_type = "rsa"
bits = 2048
days = 15
subject = "CN=Foo"

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

#puts cert

if generate
    #puts priv_key.to_pem
    puts priv_key.to_pkcs8_pem
end
