# vim: ft=make

comma := ,
empty :=
space := $(empty) $(empty)

CC       ?= gcc
CFLAGS    = -Wall -g -O1 -Wl,--as-needed

UNAME    := $(shell uname)
HOSTNAME := $(shell hostname)
MACHTYPE := $(shell dist/prepare -m)

ARCHOBJ  := obj/arch.$(MACHTYPE)
HOSTOBJ  := obj/host.$(HOSTNAME)
OBJ      := $(HOSTOBJ)
obj       = $(addprefix $(OBJ)/,$(1))

ifeq ($(UNAME),Linux)
	OSFLAGS := -DHAVE_LINUX
	KRB_LDLIBS := -lkrb5 -lcom_err
endif
ifeq ($(UNAME),FreeBSD)
	OSFLAGS := -DHAVE_FREEBSD
	KRB_LDLIBS := -lkrb5 -lcom_err
endif
ifeq ($(UNAME),NetBSD)
	OSFLAGS := -DHAVE_NETBSD
	KRB_LDLIBS := -lkrb5 -lcom_err
endif
ifeq ($(UNAME),CYGWIN_NT-5.1)
	OSFLAGS := -DHAVE_CYGWIN
	KRB_LDLIBS := -lkrb5 -lcom_err
endif
ifeq ($(UNAME),SunOS)
	OSFLAGS := -DHAVE_SOLARIS
	KRB_LDLIBS := -lkrb5
endif

override CFLAGS += $(OSFLAGS)

# misc targets

.PHONY: default pre clean mrproper

ifdef O
default: $(call obj,$(subst $(comma),$(space),$(O)))
endif

ifndef O
default: basic
endif

pre:
	@dist/prepare

clean:
	rm -rf $(ARCHOBJ) $(HOSTOBJ)

mrproper:
	git clean -dfX

# compile targets

BASIC_BINS := args pause proctool silentcat spawn strtool
KRB_BINS   := k5userok pklist
LINUX_BINS := linux26 subreaper tapchown
MISC_BINS  := bgrep logwipe natsort ttysize writevt xor xors

.PHONY: all basic krb linux misc

basic: $(call obj,$(BASIC_BINS))
krb:   $(call obj,$(KRB_BINS))
linux: $(call obj,$(LINUX_BINS))
misc:  $(call obj,$(MISC_BINS))

all: basic krb misc

ifeq ($(UNAME),Linux)
all: linux
endif

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

$(call obj,$(KRB_BINS)): LDLIBS = $(KRB_LDLIBS)

# hack for old Make (unsupported order-only deps)
dist/empty.c: pre
