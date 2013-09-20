# vim: ft=make

comma := ,
empty :=
space := $(empty) $(empty)

UNAME    := $(shell uname)
OBJ      := $(shell dist/prepare -o)

ifeq ($(origin CC),default)
CC       := gcc
endif
CFLAGS   := -pipe -Wall -O1 -g
LDFLAGS  := -Wl,--as-needed

CRYPT_LDLIBS := -lcrypt
DL_LDLIBS    := -ldl
KRB_LDLIBS   := -lkrb5 -lcom_err

ifeq ($(UNAME),Linux)
	OSFLAGS := -DHAVE_LINUX
endif
ifeq ($(UNAME),FreeBSD)
	OSFLAGS := -DHAVE_FREEBSD
	DL_LDLIBS := $(empty)
endif
ifeq ($(UNAME),GNU)
	OSFLAGS := -DHAVE_HURD
endif
ifeq ($(UNAME),NetBSD)
	OSFLAGS := -DHAVE_NETBSD
endif
ifeq ($(UNAME),OpenBSD)
	OSFLAGS := -DHAVE_OPENBSD
	CRYPT_LDLIBS := $(empty)
	DL_LDLIBS    := $(empty)
	KRB_LDLIBS   := -lkrb5 -lcom_err -lcrypto
endif
ifeq ($(UNAME),CYGWIN_NT-5.1)
	OSFLAGS := -DHAVE_CYGWIN
endif
ifeq ($(UNAME),SunOS)
	OSFLAGS := -DHAVE_SOLARIS
	KRB_LDLIBS := -lkrb5
endif

override CFLAGS += -I./misc $(OSFLAGS)

# misc targets

.PHONY: default pre clean mrproper

ifdef obj
default: $(addprefix $(OBJ)/,$(subst $(comma),$(space),$(obj)))
else
CURRENT_BINS := $(wildcard $(OBJ)/*)
ifneq ($(CURRENT_BINS),)
default: $(CURRENT_BINS)
else
default: basic
endif
endif

pre:
	@dist/prepare

clean:
	rm -rf obj/arch.* obj/dist.* obj/host.*

mrproper:
	git clean -fdX
	git checkout -f obj

# compile targets

BASIC_BINS := args mkpasswd natsort pause proctool silentcat spawn strtool zlib
KRB_BINS   := k5userok pklist
LINUX_BINS := globalenv libfunlink.so linux26 setns subreaper tapchown
MISC_BINS  := bgrep logwipe ttysize writevt xor xors

.PHONY: all basic krb linux misc pklist

basic: $(addprefix $(OBJ)/,$(BASIC_BINS))
krb:   $(addprefix $(OBJ)/,$(KRB_BINS))
linux: $(addprefix $(OBJ)/,$(LINUX_BINS))
misc:  $(addprefix $(OBJ)/,$(MISC_BINS))

all: basic krb misc
ifeq ($(UNAME),Linux)
all: linux
endif

# advertised in the pklist readme
pklist: $(OBJ)/pklist

emergency-sulogin: $(OBJ)/emergency-sulogin
	@sudo chown -v root:wheel $<
	@sudo chmod -v u=rxs,g=rx,o= $<
	@sudo cp -av $< /usr/bin/emergency-sulogin

# libraries

$(OBJ)/libfunlink.so:	CFLAGS += -shared -fPIC
$(OBJ)/libfunlink.so:	LDLIBS += $(DL_LDLIBS)
$(OBJ)/libfunlink.so:	system/libfunlink.c
$(OBJ)/libfunsync.so:	CFLAGS += -shared
$(OBJ)/libfunsync.so:	system/libfunsync.c

# objects

$(OBJ)/misc_util.o:	misc/util.c misc/util.h
$(OBJ)/strnatcmp.o:	thirdparty/strnatcmp.c

# executables

$(OBJ)/args:		misc/args.c
$(OBJ)/bgrep:		thirdparty/bgrep.c
$(OBJ)/globalenv:	LDLIBS += -lkeyutils
$(OBJ)/globalenv:	system/globalenv.c $(OBJ)/misc_util.o
$(OBJ)/k5userok:	LDLIBS += $(KRB_LDLIBS)
$(OBJ)/k5userok:	kerberos/k5userok.c
$(OBJ)/linux26:		thirdparty/linux26.c
$(OBJ)/logwipe:		thirdparty/logwipe.c
$(OBJ)/mkpasswd:	LDLIBS += $(CRYPT_LDLIBS)
$(OBJ)/mkpasswd:	security/mkpasswd.c
$(OBJ)/natsort:		thirdparty/natsort.c $(OBJ)/strnatcmp.o
$(OBJ)/pklist:		LDLIBS += $(KRB_LDLIBS)
$(OBJ)/pklist:		kerberos/pklist.c
$(OBJ)/pause:		system/pause.c
$(OBJ)/proctool:	system/proctool.c $(OBJ)/misc_util.o
$(OBJ)/setns:		system/setns.c
$(OBJ)/silentcat:	misc/silentcat.c
$(OBJ)/spawn:		system/spawn.c $(OBJ)/misc_util.o
$(OBJ)/strtool:		misc/strtool.c $(OBJ)/misc_util.o
$(OBJ)/subreaper:	system/subreaper.c
$(OBJ)/tapchown:	net/tapchown.c
$(OBJ)/ttysize:		system/ttysize.c
$(OBJ)/writevt:		thirdparty/writevt.c
$(OBJ)/xor:		misc/xor.c
$(OBJ)/xors:		misc/xors.c
$(OBJ)/zlib:		LDLIBS += -lz
$(OBJ)/zlib:		thirdparty/zpipe.c

$(OBJ)/emergency-sulogin:	LDLIBS += $(CRYPT_LDLIBS) -static
$(OBJ)/emergency-sulogin:	security/emergency-sulogin.c

# general rules

$(OBJ)/%.o:		| dist/empty.c
	@echo "  CC    $(notdir $@) ($<)"
	@$(COMPILE.c) $(OUTPUT_OPTION) $<

$(OBJ)/%:		| dist/empty.c
	@echo "  CCLD  $(notdir $@) ($<)"
	@$(LINK.c) $^ $(LOADLIBES) $(LDLIBS) -o $@

# hack for old Make (unsupported order-only deps)

dist/empty.c: pre
