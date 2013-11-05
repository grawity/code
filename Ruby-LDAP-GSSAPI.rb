require 'gssapi'
require 'net/ldap'

$host = "virgule.cluenet.org"
$base = "dc=cluenet,dc=org"

module SASL
	class GSSAPI
		# http://tools.ietf.org/html/rfc4752#section-3.1

		attr_accessor :host
		attr_accessor :service
		attr_accessor :authz

		def initialize(host, service, authz)
			@host = host
			@service = service
			@authz = authz
			@gss = nil
			@step = 0
		end

		def mechanism
			"GSSAPI"
		end

		def start
			@step = 0
			call(nil)
		end

		def call(input)
			input.force_encoding('ASCII-8BIT') if input
			#puts "<#{@step}< #{input.inspect}"
			output = case @step
				when 0
					@gss = ::GSSAPI::Simple.new(@host, "ldap")
					@gss.init_context
				when 1
					success = @gss.init_context(input)
					nil
					""
				when 2
					intoken = @gss.unwrap_message(input)
					val, = intoken.unpack('L>')
					inlayers = (val >> 24) & 0xFF
					inlength = val & 0xFFFFFF

					outlayers = 1
					outlength = 0xFFFF
					val = ((outlayers & 0xFF) << 24 |
						(outlength & 0xFFFFFF))
					outtoken = [val, @authz].pack('L>a*')
					@gss.wrap_message(outtoken, false)
				end
			output.force_encoding('UTF-8') if output
			#puts ">#{@step}> #{output.inspect}"
			@step += 1
			output
		end
	end
end

class NushLDAP
	attr_accessor :ldap
	attr_accessor :authz

	def initialize(host, base)
		@host = host
		@base = base
		@authz = ""

		@args = {host: @host,
			base: @base}

		@ldap = Net::LDAP.new(@args)

	end

	def open
		sasl = SASL::GSSAPI.new(@host, "ldap", @authz)

		@ldap.open do |ldap|
			ldap.bind(
				:method => :sasl,
				:mechanism => sasl.mechanism,
				:initial_credential => sasl.start,
				:challenge_response => sasl)

			yield ldap
		end
	end
end

ldap = NushLDAP.new($host, $base)

ldap.open do |ldap|
	p ldap.search_root_dse
end
