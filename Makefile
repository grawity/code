CCFLAGS = -Wall -O2

all: bin/args bin/bgrep bin/logwipe bin/silentcat

bootstrap:
	@bash tools/bootstrap

pull:
	@bash tools/dotrc

install: all
	@bash tools/installbin

bin/args: tools/args.c
	gcc $(CCFLAGS) -o $@ $<

bin/bgrep: tools/bgrep.c
	gcc $(CCFLAGS) -o $@ $<

bin/logwipe: tools/wipe.c
	gcc $(CCFLAGS) -o $@ $<

bin/silentcat: tools/silentcat.c
	gcc $(CCFLAGS) -o $@ $<

.PHONY: bootstrap install pull
