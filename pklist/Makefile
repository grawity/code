LIB = -lkrb5
CC = gcc
CFLAGS = -g -Wall -DHEIMDAL_TKTFLAGS

O = pklist.o strflags.o

DESTDIR = ${HOME}/bin

pklist: $(O)
	$(CC) $(CFLAGS) -o $@ $(O) $(LIB)

.c.o:
	$(CC) $(CFLAGS) -c $<

install:
	install -D pklist $(DESTDIR)

uninstall:
	rm -f $(DESTDIR)/pklist

clean:
	rm -f pklist
	rm -f *.o

.PHONY: clean
