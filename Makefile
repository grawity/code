CC	:= gcc

CFLAGS	:= -Wall -O2

BINS := \
	kerberos/k5userok	\
	kerberos/pklist		\
	misc/args		\
	misc/silentcat		\
	misc/spawn		\
	misc/xor		\
	misc/xors		\
	net/tapchown		\
	thirdparty/bgrep	\
	thirdparty/linux26	\
	thirdparty/logwipe	\
	thirdparty/natsort 	\
	thirdparty/writevt

.PHONY: all bootstrap install pull clean

all: $(BINS)

bootstrap: all
	@bash dist/bootstrap

pull:
	@bash dist/pull

install: all
	@bash dist/installbin

clean:
	git clean -dfX

kerberos/k5userok: LDLIBS := -lkrb5 -lcom_err

kerberos/pklist: LDLIBS := -lkrb5 -lcom_err

thirdparty/natsort: thirdparty/strnatcmp.c thirdparty/natsort.c
