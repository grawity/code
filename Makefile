CC	:= gcc

#CFLAGS	:= -std=gnu11 -Wall -pedantic -O2
CFLAGS	:= -Wall -O2

BINS := \
	kerberos/k5userok	\
	kerberos/pklist		\
	misc/args		\
	misc/silentcat		\
	misc/spawn		\
	misc/xor		\
	misc/xors		\
	thirdparty/bgrep	\
	thirdparty/logwipe	\
	thirdparty/natsort 	\
	thirdparty/writevt

EXTRA := \
	net/tapchown		\
	thirdparty/linux26	\

.PHONY: all bootstrap pull clean

all: $(BINS)

bootstrap: all
	@bash dist/bootstrap

pull:
	@bash dist/pull

clean:
	git clean -dfX

kerberos/k5userok: LDLIBS := -lkrb5 -lcom_err
kerberos/k5userok: kerberos/k5userok.c kerberos/krb5.h

kerberos/pklist: LDLIBS := -lkrb5 -lcom_err
kerberos/pklist: kerberos/pklist.c kerberos/krb5.h

thirdparty/natsort: thirdparty/strnatcmp.c thirdparty/natsort.c
