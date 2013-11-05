#!/usr/bin/awk -f
# For http://superuser.com/questions/569526/

BEGIN {
	freq = 10; sum = 0; max = 0
}

{
	i = NR % freq
	if (NR > freq)
		sum -= data[i]
	sum += (data[i] = $1)
	avg = sum/freq
	print "avg " avg " at " NR
}

NR >= freq {
	if (avg > max) {
		max = avg
		pos = NR
		print "new peak " max " at " pos-freq+1 ".." pos
	}
}

END {
	print "peak " max " at " pos-freq+1 ".." pos
}
