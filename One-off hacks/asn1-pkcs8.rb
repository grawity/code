require 'openssl'
require 'base64'

ASN1 = OpenSSL::ASN1

pem_data = STDIN.read

pkey = OpenSSL::PKey::RSA.new(pem_data)

key_struct = \
    ASN1::Sequence.new([
        ASN1::Integer.new(pkey.n),
        ASN1::Integer.new(pkey.e)
    ])

pkcs8_struct = \
    ASN1::Sequence.new([
        ASN1::Sequence.new([
            ASN1::ObjectId.new("rsaEncryption"),
            ASN1::Null.new(nil)
        ]),
        ASN1::BitString.new(key_struct.to_der)
    ])

puts "-----BEGIN PUBLIC KEY-----"
print Base64.encode64(pkcs8_struct.to_der)
puts "-----END PUBLIC KEY-----"
