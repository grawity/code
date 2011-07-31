CFLAGS = -Wall -O2

all:
	+make -C kerberos
	+make -C misc
	+make -C thirdparty

bootstrap: all
	@bash dist/bootstrap

pull:
	@bash dist/pull

install: all
	@bash dist/installbin

clean:
	git clean -dfX

.PHONY: all bootstrap install pull clean
