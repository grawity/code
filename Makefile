install: all
	bash tools/installbin

all: bin/args bin/bgrep bin/logwipe

bin/args: tools/args.c
	gcc -Wall -o $@ $<

bin/bgrep: tools/bgrep.c
	gcc -Wall -o $@ $<

bin/logwipe: tools/wipe.c
	gcc -Wall -o $@ $<

.PHONY: install
