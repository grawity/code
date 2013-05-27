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
		if vec[i] =~ /^:/
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
			if args[i] =~ /\s/
				raise "Argument #{i} contains whitespace"
			end
			vec << args[i]
			i += 1
		end
		if args[i] =~ /\s/
			raise "Argument #{i} contains whitespace"
		end
		if args[i] =~ /^:/
			if args[i] =~ /\s/
				raise "Argument #{i} contains whitespace"
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
			elsif args[i] =~ /\s/
				raise "Argument #{i} contains whitespace"
			end
			vec << args[i]
			i += 1
		end
		if i == n
			if args[i].empty? or args[i] =~ /^:/ or args[i] =~ /\s/
				vec << ":" + args[i]
			else
				vec << args[i]
			end
		end
		return vec.join(" ")
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
