IrcMessage = Struct.new(:tags, :prefix, :argv)

def parse(str)
	vec = str.chomp.split(" ")
	i = 0
	tags = nil
	prefix = nil
	argv = []
	if vec[i].start_with? "@"
		tags = vec[i][1..-1]
		i += 1
	end
	if vec[i].start_with? ":"
		prefix = vec[i][1..-1]
		i += 1
	end
	while i < vec.length and !vec[i].start_with? ":"
		argv << vec[i]
		i += 1
	end
	if vec[i]
		trailing = vec[i..-1].join(" ")
		argv << trailing[1..-1]
	end
	return IrcMessage.new(tags, prefix, argv)
end
