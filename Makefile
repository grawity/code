all: bin/args bin/bgrep bin/logwipe

bootstrap:
	@bash tools/bootstrap

pull:
	@bash tools/dotrc

install: all
	@bash tools/installbin

bin/args: tools/args.c
	gcc -Wall -o $@ $<

bin/bgrep: tools/bgrep.c
	gcc -Wall -o $@ $<

bin/logwipe: tools/wipe.c
	gcc -Wall -o $@ $<

.PHONY: bootstrap install pull
