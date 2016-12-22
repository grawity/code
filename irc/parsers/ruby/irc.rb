# Parser for IRC protocol messages (RFC 1459 + IRCv3 message-tag extension)
#
# (c) 2012-2014 Mantas Mikulėnas <grawity@gmail.com>
# Released under the MIT License (dist/LICENSE.mit)

class IRC
	def self.parse(str)
		vec = str.chomp.split(/ /, -1)
		i = 0
		tags = nil
		prefix = nil
		argv = []
		while vec[i] and vec[i].empty?
			i += 1
		end
		if vec[i] =~ /^@/
			tags = vec[i][1..-1]
			i += 1
			while vec[i] and vec[i].empty?
				i += 1
			end
		end
		if vec[i] =~ /^:/ and vec[i + 1]
			prefix = vec[i][1..-1]
			i += 1
			while vec[i] and vec[i].empty?
				i += 1
			end
		end
		while i < vec.length and vec[i] !~ /^:/
			argv << vec[i]
			i += 1
			while vec[i] and vec[i].empty?
				i += 1
			end
		end
		if vec[i]
			trailing = vec[i..-1].join(" ")
			argv << trailing[1..-1]
		end
		return IRC::Message.new(tags, prefix, argv)
	end

	def self.join(args)
		i = 0
		vec = []
		args = args.map(&:to_s)
		if args[i] =~ /^@/
			if args[i] =~ / /
				raise "Argument #{i} contains spaces"
			end
			vec << args[i]
			i += 1
		end
		if args[i] =~ / /
			raise "Argument #{i} contains spaces"
		end
		if args[i] =~ /^:/
			if args[i] =~ / /
				raise "Argument #{i} contains spaces"
			end
			vec << args[i]
			i += 1
		end
		n = args.length - 1
		while i < n
			if args[i].empty?
				raise "Argument #{i} is empty"
			elsif args[i] =~ /^:/
				raise "Argument #{i} starts with ':'"
			elsif args[i] =~ / /
				raise "Argument #{i} contains spaces"
			end
			vec << args[i]
			i += 1
		end
		if i == n
			if args[i].empty? or args[i] =~ /^:/ or args[i] =~ / /
				vec << ":" + args[i]
			else
				vec << args[i]
			end
		end
		return vec.join(" ")
	end
end

class IRC::Prefix < Struct.new(:nick, :user, :host, :is_server?)
	def self.parse(str)
		if str.length == 0
			raise "Nickname is empty"
		end

		dpos = str.index(".")
		upos = str.index("!")
		hpos = str.index("@", upos || 0)

		dpos ||= -1
		upos ||= -1
		hpos ||= -1

		if 0 <= hpos and hpos < upos
			upos = -1
		end

		if upos == 0 || hpos == 0
			raise "Nickname is empty"
		end

		if 0 <= dpos && (dpos < upos && dpos < hpos)
			raise "Nickname contains dots"
		end

		nick = nil
		user = nil
		host = nil
		is_server = false

		if upos >= 0
			nick = str[0..upos-1]
			if hpos >= 0
				user = str[upos+1..hpos-1]
				host = str[hpos+1..-1]
			else
				user = str[upos+1..-1]
			end
		elsif hpos >= 0
			nick = str[0..hpos-1]
			host = str[hpos+1..-1]
		elsif dpos >= 0
			host = str
			is_server = true
		else
			nick = str
		end

		return IRC::Prefix.new(nick, user, host, is_server)
	end
end

class IRC::Message < Struct.new(:tags, :prefix, :argv)
	def to_a
		vec = []
		vec << "@" + tags	if tags
		vec << ":" + prefix	if prefix
		vec += argv			if argv
		return vec
	end

	def unparse
		return IRC.join(self.to_a)
	end
end

# vim: ts=4:sw=4
