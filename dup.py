import sys

def read_data():
	d = {}
	for line in open(sys.argv[1]):
		k, v = line.strip().split(None, 1)
		if k in d:
			d[k].append(v)
		else:
			d[k] = [v]
	return d

def find_dups(dic):
	for key, val in dic.items():
		if len(val) > 1:
			yield key, val


def display(key, val):
	IND = " " * 4
	print key
	print IND + ("\n"+IND).join(val)

input = read_data()
for k, v in find_dups(input):
	display(k, v)