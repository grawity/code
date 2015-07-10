def bin(num, sz=8):
	b = []
	while num:
		rem = int(num % 2)
		b.append(rem)
		num -= rem
		num /= 2
	while len(b) % sz:
		b.append(0)
	b.reverse()
	return ''.join(map(str, b))

def dump(num, sz=8):
	return "".join(bin(x, sz) for x in num)
