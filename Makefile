#!make

UNAME := $(shell uname)
HOSTNAME := $(shell hostname)
#MACHTYPE := $(shell cc -dumpmachine)
MACHTYPE := $(shell bash -c 'echo $$MACHTYPE')

ARCHOBJ := obj/arch.$(MACHTYPE)
HOSTOBJ := obj/host.$(HOSTNAME)
OBJ := $(HOSTOBJ)

CC ?= gcc
CFLAGS = -Wall -O2 $(OSFLAGS)

KRB_LDLIBS := -lkrb5 -lcom_err

ifeq ($(UNAME),Linux)
	OSFLAGS := -DHAVE_LINUX
endif
ifeq ($(UNAME),FreeBSD)
	OSFLAGS := -DHAVE_FREEBSD
endif
ifeq ($(UNAME),NetBSD)
	OSFLAGS := -DHAVE_NETBSD
endif
ifeq ($(UNAME),CYGWIN_NT-5.1)
	OSFLAGS := -DHAVE_CYGWIN
endif
ifeq ($(UNAME),SunOS)
	OSFLAGS := -DHAVE_SOLARIS
	KRB_LDLIBS := -lkrb5
endif

# misc targets

.PHONY: pre all basic clean mrproper

DEFAULT: basic

pre:
	@dist/prepare

clean:
	rm -rf $(ARCHOBJ) $(HOSTOBJ)

mrproper:
	git clean -dfX

# compile targets

BASIC_BINS := args pause proctool silentcat spawn strtool
KRB_BINS := k5userok pklist
LINUX_BINS := linux26 subreaper tapchown
MISC_BINS := bgrep logwipe natsort ttysize writevt xor xors

cc-basic: $(addprefix $(OBJ)/,$(BASIC_BINS))
cc-krb: $(addprefix $(OBJ)/,$(KRB_BINS))
cc-linux: $(addprefix $(OBJ)/,$(LINUX_BINS))
cc-misc: $(addprefix $(OBJ)/,$(MISC_BINS))
pklist: $(OBJ)/pklist

cc-all: cc-basic cc-krb cc-misc
ifeq ($(UNAME),Linux)
cc-all: cc-linux
endif

basic: cc-basic

all: cc-all

$(addprefix $(OBJ)/,$(KRB_BINS)): LDLIBS = $(KRB_LDLIBS)

$(OBJ)/args:		misc/args.c
$(OBJ)/bgrep:		thirdparty/bgrep.c
$(OBJ)/k5userok:	kerberos/k5userok.c | kerberos/krb5.h
$(OBJ)/linux26:		thirdparty/linux26.c
$(OBJ)/logwipe:		thirdparty/logwipe.c
$(OBJ)/natsort:		thirdparty/natsort.c thirdparty/strnatcmp.c
$(OBJ)/pklist:		kerberos/pklist.c | kerberos/krb5.h
$(OBJ)/pause:		misc/pause.c
$(OBJ)/proctool:	misc/proctool.c misc/util.c | misc/util.h
$(OBJ)/silentcat:	misc/silentcat.c
$(OBJ)/spawn:		misc/spawn.c
$(OBJ)/strtool:		misc/strtool.c misc/util.c | misc/util.h
$(OBJ)/subreaper:	misc/subreaper.c
$(OBJ)/tapchown:	net/tapchown.c
$(OBJ)/ttysize:		misc/ttysize.c
$(OBJ)/writevt:		thirdparty/writevt.c
$(OBJ)/xor:		misc/xor.c
$(OBJ)/xors:		misc/xors.c

$(OBJ)/%:		| dist/empty.c
	$(LINK.c) $^ $(LOADLIBES) $(LDLIBS) -o $@

# hack for old Make (unsupported order-only deps)
dist/empty.c: pre
