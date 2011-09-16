CC	= gcc
CFLAGS	= -Wall -O2

BIN = \
	kerberos/pklist \
	misc/args \
	misc/silentcat \
	misc/xor \
	misc/xors \
	thirdparty/bgrep \
	thirdparty/logwipe \
	thirdparty/writevt

all: $(BIN)

bootstrap: all
	@bash dist/bootstrap

pull:
	@bash dist/pull

install: all
	@bash dist/installbin

clean:
	git clean -dfX

kerberos/pklist: kerberos/pklist.c
	$(CC) $(CFLAGS) $(LDFLAGS) -lkrb5 -lcom_err $< -o $@

.PHONY: all bootstrap install pull clean
