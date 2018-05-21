#!/usr/bin/env ruby
require 'openssl'

# - install libp11 to obtain the pkcs11 engine
# - specifying its path is optional for 1.1
#engine_lib = "/usr/lib/engines-1.1/pkcs11.so"
engine_lib = nil

pkcs11_lib = "/usr/lib/libsofthsm2.so"

# first obtain token URL with `p11tool --list-tokens`
# then obtain the object URL with `p11tool <token_url> --login --list-keys`
token_id = "pkcs11:model=SoftHSM%20v2;manufacturer=SoftHSM%20project;serial=2b544e6223dfb5ed;token=Nullroute%20CA%20r4;id=%df%b4%01%98%c6%0d%fa%4f;object=Nullroute%20CA%20r4"
token_pin = nil

OpenSSL::Engine.load()
if engine_lib
	e = OpenSSL::Engine.by_id("dynamic") do |e|
                e.ctrl_cmd("SO_PATH", engine_lib)
                e.ctrl_cmd("ID", "pkcs11")
                e.ctrl_cmd("LOAD")
		e.ctrl_cmd("PIN", token_pin) if token_pin
		e.ctrl_cmd("MODULE_PATH", pkcs11_lib)
	end
else
	e = OpenSSL::Engine.by_id("pkcs11") do |e|
		e.ctrl_cmd("PIN", token_pin) if token_pin
		e.ctrl_cmd("MODULE_PATH", pkcs11_lib)
	end
end
key = e.load_private_key(token_id)
# acts as a regular OpenSSL::PKey
p key.sign(OpenSSL::Digest::SHA1.new, "foobar")
