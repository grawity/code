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

BASIC_BINS := args gettime mkpasswd natsort natxsort pause silentcat spawn unescape
BASIC_BINS += ac-wait entropy proctool strtool subreaper xor xors xorf
KRB_BINS   := k5userok pklist
MISC_BINS  := libwcwidth.so logwipe writevt zlib
LINUX_BINS := globalenv libfunlink.so libfunsync.so peekvc showsigmask statx tapchown

.PHONY: all basic krb misc linux pklist

basic: $(addprefix $(OBJ)/,$(BASIC_BINS))
krb:   $(addprefix $(OBJ)/,$(KRB_BINS))
misc:  $(addprefix $(OBJ)/,$(MISC_BINS))
linux: $(addprefix $(OBJ)/,$(LINUX_BINS))

all: basic krb misc
ifeq ($(UNAME),Linux)
all: linux
endif

pklist: $(OBJ)/pklist

emergency-su: $(OBJ)/emergency-su
	sudo install -o 'root' -g 'wheel' -m 'u=rxs,g=rx,o=' $< /usr/bin/$@

# libraries

$(OBJ)/libdark.so:	CFLAGS += $(pkg-config x11 --cflags) -shared -fPIC
$(OBJ)/libdark.so:	LDLIBS += $(pkg-config x11 --libs)
$(OBJ)/libdark.so:	desktop/libdark.c

$(OBJ)/libfunlink.so:	CFLAGS += -shared -fPIC
$(OBJ)/libfunlink.so:	LDLIBS += $(DL_LDLIBS)
$(OBJ)/libfunlink.so:	system/libfunlink.c

$(OBJ)/libfunsync.so:	CFLAGS += -shared
$(OBJ)/libfunsync.so:	system/libfunsync.c

$(OBJ)/libwcwidth.so:	CFLAGS += -shared -fPIC \
				-Dmk_wcwidth=wcwidth -Dmk_wcswidth=wcswidth
$(OBJ)/libwcwidth.so:	thirdparty/wcwidth.c

# objects

$(OBJ)/misc_util.o:	misc/util.c misc/util.h
$(OBJ)/strnatcmp.o:	thirdparty/strnatcmp.c
$(OBJ)/strnatxcmp.o:	CFLAGS += -DNATSORT_HEX
$(OBJ)/strnatxcmp.o:	thirdparty/strnatcmp.c

# executables

$(OBJ)/ac-wait:		LDLIBS += -ludev
$(OBJ)/ac-wait:		system/ac-wait.c
$(OBJ)/args:		misc/args.c
$(OBJ)/entropy:		LDLIBS += -lm
$(OBJ)/entropy:		security/entropy.c
$(OBJ)/gettime:		LDLIBS += -lrt
$(OBJ)/gettime:		misc/gettime.c
$(OBJ)/globalenv:	LDLIBS += -lkeyutils
$(OBJ)/globalenv:	system/globalenv.c $(OBJ)/misc_util.o
$(OBJ)/codeset:		misc/codeset.c
$(OBJ)/k5userok:	LDLIBS += $(KRB_LDLIBS)
$(OBJ)/k5userok:	kerberos/k5userok.c
$(OBJ)/logwipe:		thirdparty/logwipe.c
$(OBJ)/mkpasswd:	LDLIBS += $(CRYPT_LDLIBS)
$(OBJ)/mkpasswd:	security/mkpasswd.c
$(OBJ)/natsort:		thirdparty/natsort.c $(OBJ)/strnatcmp.o
$(OBJ)/natxsort:	thirdparty/natsort.c $(OBJ)/strnatxcmp.o
$(OBJ)/peekvc:		thirdparty/peekvc.c
$(OBJ)/pklist:		LDLIBS += $(KRB_LDLIBS)
$(OBJ)/pklist:		kerberos/pklist.c
$(OBJ)/pause:		system/pause.c
$(OBJ)/proctool:	system/proctool.c $(OBJ)/misc_util.o
$(OBJ)/showsigmask:	system/showsigmask.c
$(OBJ)/silentcat:	misc/silentcat.c
$(OBJ)/spawn:		system/spawn.c $(OBJ)/misc_util.o
$(OBJ)/strtool:		misc/strtool.c
$(OBJ)/subreaper:	system/subreaper.c
$(OBJ)/tapchown:	net/tapchown.c
$(OBJ)/unescape:	misc/unescape.c
$(OBJ)/urlencode:	misc/urlencode.c
$(OBJ)/writevt:		thirdparty/writevt.c
$(OBJ)/xor:		misc/xor.c
$(OBJ)/xorf:		misc/xorf.c
$(OBJ)/xors:		misc/xors.c
$(OBJ)/zlib:		LDLIBS += -lz
$(OBJ)/zlib:		thirdparty/zpipe.c

$(OBJ)/gl-mem:		CFLAGS += $(shell pkg-config x11 epoxy --cflags)
$(OBJ)/gl-mem:		LDLIBS += $(shell pkg-config x11 epoxy --libs)
$(OBJ)/gl-mem:		desktop/gl-mem.c

$(OBJ)/emergency-su:	LDLIBS += $(CRYPT_LDLIBS) -static
$(OBJ)/emergency-su:	security/emergency-su.c
