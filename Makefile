#!/usr/bin/make -f

include dist/shared.mk

override CFLAGS += -I./misc

# misc targets

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

$(dummy): $(OBJ)/config.h
$(dummy): $(OBJ)/config-krb5.h
	$(verbose_hide) touch $@

# compile targets

BASIC_BINS := args gettime mkpasswd natsort pause spawn unescape urlencode
BASIC_BINS += entropy hex unhex proctool strtool xor xors xorf
KRB_BINS   := k5userok pklist
MISC_BINS  := ac-wait libwcwidth.so logwipe writevt zlib
LINUX_BINS := libfunsync.so ssh_force_lp.so unsymlink.so peekvc showsigmask statx tapchown

.PHONY: all basic krb misc linux pklist

basic: $(addprefix $(OBJ)/,$(BASIC_BINS))
krb:   $(addprefix $(OBJ)/,$(KRB_BINS))
misc:  $(addprefix $(OBJ)/,$(MISC_BINS))
linux: $(addprefix $(OBJ)/,$(LINUX_BINS))

desktop: $(OBJ)/ac-wait
desktop: $(OBJ)/spawn

all: basic krb misc
ifeq ($(UNAME),Linux)
all: linux
endif

pklist: $(OBJ)/pklist

emergency-su: $(OBJ)/emergency-su
	sudo install -o 'root' -g 'wheel' -m 'u=rxs,g=rx,o=' $< /usr/bin/$@

# libraries

$(OBJ)/libfunsync.so:	CFLAGS += -shared
$(OBJ)/libfunsync.so:	system/libfunsync.c

$(OBJ)/ssh_force_lp.so:	CFLAGS += -shared
$(OBJ)/ssh_force_lp.so:	net/ssh_force_lp.c

$(OBJ)/unsymlink.so:	CFLAGS += -shared
$(OBJ)/unsymlink.so:	LDLIBS += $(DL_LDLIBS)
$(OBJ)/unsymlink.so:	system/unsymlink.c

$(OBJ)/libwcwidth.so:	CFLAGS += -shared -fPIC \
				-Dmk_wcwidth=wcwidth -Dmk_wcswidth=wcswidth
$(OBJ)/libwcwidth.so:	thirdparty/wcwidth.c

# objects

$(OBJ)/misc_util.o:	misc/util.c misc/util.h
$(OBJ)/strnatcmp.o:	thirdparty/strnatcmp.c

# executables

$(OBJ)/ac-wait:		LDLIBS += -ludev
$(OBJ)/ac-wait:		system/ac-wait.c
$(OBJ)/args:		misc/args.c
$(OBJ)/entropy:		LDLIBS += -lm
$(OBJ)/entropy:		security/entropy.c
$(OBJ)/gettime:		LDLIBS += -lrt
$(OBJ)/gettime:		misc/gettime.c
$(OBJ)/hex:		misc/hex.c
$(OBJ)/k5userok:	CFLAGS += $(KRB_CFLAGS)
$(OBJ)/k5userok:	LDLIBS += $(KRB_LDLIBS)
$(OBJ)/k5userok:	kerberos/k5userok.c
$(OBJ)/logwipe:		thirdparty/logwipe.c
$(OBJ)/mkpasswd:	LDLIBS += $(CRYPT_LDLIBS)
$(OBJ)/mkpasswd:	security/mkpasswd.c
$(OBJ)/natsort:		thirdparty/natsort.c $(OBJ)/strnatcmp.o
$(OBJ)/peekvc:		thirdparty/peekvc.c
$(OBJ)/pklist:		CFLAGS += $(KRB_CFLAGS)
$(OBJ)/pklist:		LDLIBS += $(KRB_LDLIBS)
$(OBJ)/pklist:		kerberos/pklist.c
$(OBJ)/pause:		system/pause.c
$(OBJ)/proctool:	system/proctool.c $(OBJ)/misc_util.o
$(OBJ)/showsigmask:	CFLAGS += -I$(OBJ)
$(OBJ)/showsigmask:	system/showsigmask.c
$(OBJ)/spawn:		system/spawn.c $(OBJ)/misc_util.o
$(OBJ)/statx:		system/statx.c
$(OBJ)/strtool:		misc/strtool.c
$(OBJ)/tapchown:	net/tapchown.c
$(OBJ)/unescape:	misc/unescape.c
$(OBJ)/unhex:		misc/unhex.c
$(OBJ)/urlencode:	misc/urlencode.c
$(OBJ)/writevt:		thirdparty/writevt.c
$(OBJ)/xor:		misc/xor.c
$(OBJ)/xorf:		misc/xorf.c
$(OBJ)/xors:		misc/xors.c
$(OBJ)/zlib:		LDLIBS += -lz
$(OBJ)/zlib:		thirdparty/zpipe.c

$(OBJ)/newrdt:		LDLIBS += -lresolv
$(OBJ)/newrdt:		net/rdt.c

$(OBJ)/gl-mem:		CFLAGS += $(shell pkg-config --cflags x11 epoxy)
$(OBJ)/gl-mem:		LDLIBS += $(shell pkg-config --libs x11 epoxy)
$(OBJ)/gl-mem:		desktop/gl-mem.c

$(OBJ)/emergency-su:	LDLIBS += $(CRYPT_LDLIBS) -static
$(OBJ)/emergency-su:	security/emergency-su.c
