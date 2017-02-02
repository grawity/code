import os

def gets(prompt=None):
	prompt = "%s " % (prompt or "%")
	if hasattr(__builtins__, "raw_input"):
		return raw_input(prompt)
	elif hasattr(__builtins__, "input"):
		return input(prompt)
	else:
		raise NotImplementedError

class ParserError(Exception):
	pass

class Stack(list):
	def push(self, *items):
		return self.extend(items)

	@property
	def last(self):
		return self[-1]

	@last.setter
	def last(self, value):
		self[-1] = value

	def prev(self, n=1):
		return self[-1-n]

class Parser(object):
	escapes = {
		"e": "\033",
		"n": "\n",
		"t": "\t",
	}

	parse_bquoted = True

	def __init__(self):
		self.reset()

	def reset(self):
		self.state = Stack(["raw"])
		self.cur = ""
		self.words = []
		self.append = False
		return True

	def feed(self, line, multiline=True):
		i = 0
		append = False
		done = True
		variables = os.environ

		while i <= len(line):
			char = line[i] if i < len(line) else None
			#print("%r %r %r" % (self.words, char, self.state))
			if self.state.last == "raw":
				if not char or char.isspace():
					if self.cur or append:
						self.words.append(self.cur)
						self.cur = ""
						append = False
				elif char == "\"":
					self.state.push("dquoted")
				elif char == "'":
					self.state.push("squoted")
				elif char == "{" and self.parse_bquoted:
					self.state.push("bquoted")
				elif char == "\\":
					self.state.push("escape")
				elif char == "$" and variables is not None:
					token = ""
					self.state.push("variable")
				else:
					self.cur += char
			elif self.state.last == "escape":
				if not char:
					done = False
					i -= 1
					self.state.pop()
				elif char == "x":
					token = ""
					self.state.last = "escape hex"
				elif char in "0123":
					token = char
					self.state.last = "escape oct"
				elif char in self.escapes:
					self.cur += self.escapes[char]
					append = True
					self.state.pop()
				else:
					self.cur += char
					self.state.pop()
			elif self.state.last == "escape hex":
				if char and char in "0123456789abcdefABCDEF":
					token += char
					if len(token) == 2:
						self.cur += chr(int(token, 16))
						self.state.pop()
				else:
					raise ParserError("invalid hex character %r" % char)
			elif self.state.last == "escape oct":
				if char and char in "01234567" and len(token) < 3:
					token += char
				else:
					self.cur += chr(int(token, 8))
					i -= 1
					self.state.pop()
			elif self.state.last == "dquoted":
				if char == "\"":
					append = True
					self.state.pop()
				elif char == "\\":
					self.state.push("escape")
				elif char == "$" and variables is not None:
					token = ""
					self.state.push("variable")
				elif char:
					self.cur += char
				elif multiline:
					done = False
					break
				else:
					raise ParserError("missing closing \"")
			elif self.state.last == "squoted":
				if char == "'":
					append = True
					self.state.pop()
				elif char:
					self.cur += char
				elif multiline:
					done = False
					break
				else:
					raise ParserError("missing closing '")
			elif self.state.last == "bquoted":
				if char == "}":
					if self.state.prev(1) == "bquoted":
						self.cur += char
					append = True
					self.state.pop()
				elif char == "{":
					self.cur += char
					state.push("bquoted")
				elif char == "\\":
					state.push("escape")
				elif char:
					self.cur += char
				else:
					done = False
					break
			elif self.state.last == "variable":
				var = None

				if char and char in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"\
							"abcdefghijklmnopqrstuvwxyz"\
							"0123456789_":
					token += char
				elif char == "$" and not token:
					var = str(os.getpid())
				elif char == "{" and not token:
					token += char
				elif token and token[0] == "{":
					if char == "}":
						var = variables.get(token[1:], "")
					elif multiline:
						done = False
						break
					else:
						raise ParserError("missing closing }")
				else:
					i -= 1
					var = variables.get(token, "")

				if var is not None:
					if self.state.prev() == "raw":
						var = (self.cur+var).split()
						if var:
							self.cur = var.pop()
							for token in var:
								if token or append:
									self.words.append(token)
									append = False
					else:
						self.cur += var
					self.state.pop()
			i += 1

		if not multiline:
			done = True

		if not done:
			err = None
		elif not self.state or self.state.last == "raw":
			err = None
		elif self.state.last in ("bquoted", "variable"):
			raise ParserError("missing closing }")
		elif self.state.last == "escape":
			raise ParserError("extra backslash")
		elif self.state.last == "escape hex":
			raise ParserError("truncated hex escape")
		elif self.state.last == "escape oct":
			raise ParserError("truncated oct escape")
		else:
			raise ParserError("foo")
		
		if done:
			return self.words, self.reset()
		else:
			return self.words, False

line = ""
done = True

parser = Parser()

while True:
	if done:
		line = gets("%")
	else:
		line = "\n" + gets("...")

	try:
		words, done = parser.feed(line)
	except ParserError as e:
		print("syntax error:", e)
	else:
		print(words, done)