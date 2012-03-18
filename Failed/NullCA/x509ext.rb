class Ext
	def self.subjectAltName(names)
		Extlib::extension("subjectAltName", false,
			Extlib::subjectAltName(
				names.map{|i| Extlib::GeneralName(i)}))
	end
end

class Extlib
	def self.extension(extnID, critical, extnValue)
		OpenSSL::X509::Extension.new(extnID, extnValue, critical)
	end

	def self.subjectAltName(values)
		OpenSSL::ASN1::Sequence.new(values)
	end

	def self.GeneralName(name)
		m = name.match("^([^:]+):(.+)$")
		case m[1]
		when "XMPP"
			# otherName [0]
			OpenSSL::ASN1::Sequence.new([
				OpenSSL::ASN1::ObjectId.new("1.3.6.1.5.5.7.8.5"),
				OpenSSL::ASN1::UTF8String.new(m[2], 0, :EXPLICIT),
			], 0, :IMPLICIT)
		when "email"
			# rfc822name [1]
			OpenSSL::ASN1::IA5String.new(m[2], 1, :IMPLICIT)
		when "DNS"
			# dNSName [2]
			OpenSSL::ASN1::IA5String.new(m[2], 2, :IMPLICIT)
		when "URI"
			# uniformResourceIdentifier [6]
			OpenSSL::ASN1::IA5String.new(m[2], 6, :IMPLICIT)
		else
			# http://www.alvestrand.no/objectid/2.5.29.17.html
			raise "Unknown subjectAltName syntax: #{name}"
		end
	end
end

