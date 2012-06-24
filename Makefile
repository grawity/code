CC = gcc

CFLAGS = -Wall -O2 $(OSFLAGS)

UNAME := $(shell uname)

OBJDIR := $(shell bash -c 'echo obj/$$HOSTTYPE-$$OSTYPE')

ifeq ($(UNAME),Linux)
	OSFLAGS := -DHAVE_LINUX
else ifeq ($(UNAME),FreeBSD)
	OSFLAGS := -DHAVE_FREEBSD
else ifeq ($(UNAME),NetBSD)
	OSFLAGS := -DHAVE_NETBSD
else ifeq ($(UNAME),CYGWIN_NT-5.1)
	OSFLAGS := -DHAVE_CYGWIN
endif

BINS = \
	misc/args		\
	misc/silentcat		\
	misc/spawn

EXTRA = \
	kerberos/k5userok	\
	kerberos/pklist		\
	misc/xor		\
	misc/xors		\
	net/tapchown		\
	thirdparty/bgrep	\
	thirdparty/linux26	\
	thirdparty/logwipe	\
	thirdparty/natsort	\
	thirdparty/writevt

.PHONY: all bootstrap pull clean

basic: $(BINS)

all: basic $(EXTRA)

bootstrap: basic
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
