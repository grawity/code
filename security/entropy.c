/* entropy -- calculate Shannon entropy of a given string
 *
 * Portions from LibreSwan (lib/libswan/secrets.c)
 * Copyright (C) 2012-2013 Paul Wouters <paul@libreswan.org>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.  See <http://www.fsf.org/copyleft/gpl.txt>.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 */
#include <math.h>
#include <stdio.h>
#include <string.h>

#define MIN_SHANNON_ENTROPY 3.5
#define UCHAR_MAX 255
#define zero(x) memset((x), '\0', sizeof(*(x)))

static double shannon_entropy(const unsigned char *p, size_t size)
{
	double entropy = 0.0;
	int histogram[UCHAR_MAX + 1];
	unsigned int i;

	zero(&histogram);

	for (i = 0; i < size; ++i)
		++histogram[p[i]];

	for (i = 0; i <= UCHAR_MAX; ++i) {
		if (histogram[i] != 0) {
			double p = (double)histogram[i] / size;

			entropy -=  p * log2(p);
		}
	}

        return entropy;
}

int main(int argc, char *argv[]) {
	int i;
	char *p;
	double e;

	for (i = 1; i < argc; i++) {
		p = argv[i];
		e = shannon_entropy((unsigned char *)p, strlen(p));
		printf("Shannon entropy of \"%s\" is %f (%s)\n", p, e,
			e < MIN_SHANNON_ENTROPY ? "bad" : "good");
	}

	return 0;
}
