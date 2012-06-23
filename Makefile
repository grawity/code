UNAME	:= $(shell uname)

ifeq ($(UNAME),Linux)
	OSFLAGS := -DHAVE_LINUX
else ifeq ($(UNAME),FreeBSD)
	OSFLAGS := -DHAVE_FREEBSD
else ifeq ($(UNAME),NetBSD)
	OSFLAGS := -DHAVE_NETBSD
else ifeq ($(UNAME),CYGWIN_NT-5.1)
	OSFLAGS := -DHAVE_CYGWIN
endif

CC	:= gcc

#CFLAGS	:= -std=gnu11 -Wall -pedantic -O2
CFLAGS	:= -Wall -O2 $(OSFLAGS)

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
	thirdparty/writevt

EXTRA := \
	net/tapchown		\
	thirdparty/linux26	\
	thirdparty/natsort

.PHONY: all bootstrap pull clean

all: $(BINS)

extra: all $(EXTRA)

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
