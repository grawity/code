struct ParsedLine {
	public string tags;
	public string sender;
	public string command;
	public string[] args;
}

string[] split_irc_line(string line) {
	var args = line.split(" ");
	string[] parsed = {};
	int i = 0, n = args.length;
	if (i < n && args[i].has_prefix("@")) {
		parsed += args[i++];
		while (i < n && args[i] == "")
			i++;
	}
	if (i + 1 < n && args[i].has_prefix(":")) {
		parsed += args[i++];
		while (i < n && args[i] == "")
			i++;
	}
	while (i < n) {
		if (args[i].has_prefix(":"))
			break;
		else if (args[i] != "")
			parsed += args[i];
		i++;
	}
	if (i < n) {
		args[i] = args[i].substring(1);
		parsed += string.joinv(" ", args[i:n]);
	}
	return parsed;
}

ParsedLine parse_irc_line(string line) {
	var args = split_irc_line(line);
	var parsed = ParsedLine();
	int i = 0, n = args.length;
	if (i < n && args[i].has_prefix("@"))
		parsed.tags = args[i++];
	if (i < n && args[i].has_prefix(":"))
		parsed.sender = args[i++];
	if (i < n)
		parsed.command = args[i++].up();
	if (i < n)
		parsed.args = args[i:n];
	return parsed;
}

/* example functions */

void test_parser(string input) {
	print("INPUT '" + input + "'\n");
	var output = parse_irc_line(input);
	print("tags    '" + output.tags + "'\n");
	print("sender  '" + output.sender + "'\n");
	print("command '" + output.command + "'\n");
	foreach (string arg in output.args)
		print("arg     '" + arg + "'\n");
	print("---\n");
}

int main(string[] args) {
	test_parser("@tag=tag,tag=tag :nick!user@host privmsg #something :hi this is a test");
	test_parser("TOPIC one two :three four");
	test_parser(":host.example.com 123 one two three");
	return 0;
}
