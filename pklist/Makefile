LIB = -lkrb5
CC = gcc
CFLAGS = -g -Wall $(D)

DESTDIR = ${HOME}/bin

pklist: pklist.c
	$(CC) $(CFLAGS) -o $@ pklist.c $(LIB)

install:
	install -D pklist $(DESTDIR)

uninstall:
	rm -f $(DESTDIR)/pklist

clean:
	rm -f pklist
	rm -f *.o

.PHONY: clean
