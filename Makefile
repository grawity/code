CFLAGS = -Wall -O2

all:
	+make -C kerberos
	+make -C thirdparty
	+make -C tools

bootstrap: all
	@bash dist/bootstrap

pull:
	@bash dist/pull

install: all
	@bash dist/installbin

clean:
	+make -C kerberos clean
	+make -C thirdparty clean
	+make -C tools clean

.PHONY: bootstrap install pull clean
