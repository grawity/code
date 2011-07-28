CFLAGS = -Wall -O2

all: bin/args bin/bgrep bin/logwipe bin/silentcat

bootstrap:
	@bash dist/bootstrap

pull:
	@bash dist/pull

install: all
	@bash dist/installbin

clean:
	rm -f bin/*

bin/args: tools/args.c
	gcc $(CFLAGS) -o $@ $<

bin/bgrep: tools/bgrep.c
	gcc $(CFLAGS) -o $@ $<

bin/logwipe: tools/logwipe.c
	gcc $(CFLAGS) -o $@ $<

bin/silentcat: tools/silentcat.c
	gcc $(CFLAGS) -o $@ $<

kerberos:
	@make -C kerberos

.PHONY: bootstrap install pull clean
.PHONY: kerberos
