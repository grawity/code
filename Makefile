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

.PHONY: basic
basic: $(OBJ)/args
basic: $(OBJ)/gettime
basic: $(OBJ)/mkpasswd
basic: $(OBJ)/natsort
basic: $(OBJ)/pause
basic: $(OBJ)/spawn
basic: $(OBJ)/unescape
basic: $(OBJ)/urlencode
basic: $(OBJ)/hex
basic: $(OBJ)/unhex
basic: $(OBJ)/proctool
basic: $(OBJ)/strtool
basic: $(OBJ)/zlib

.PHONY: linux
linux: $(OBJ)/ac-wait
linux: $(OBJ)/libfunsync.so
linux: $(OBJ)/libwcwidth.so
linux: $(OBJ)/ssh_force_lp.so
linux: $(OBJ)/unsymlink.so
linux: $(OBJ)/peekvc
linux: $(OBJ)/showsigmask
linux: $(OBJ)/statx
linux: $(OBJ)/tapchown
linux: $(OBJ)/writevt

.PHONY: krb
krb: $(OBJ)/k5userok
krb: $(OBJ)/pklist

.PHONY: all
all: basic krb
ifeq ($(UNAME),Linux)
all: linux
endif

.PHONY: pklist
pklist: $(OBJ)/pklist

emergency-su: $(OBJ)/emergency-su
	sudo install -o 'root' -g 'wheel' -m 'u=rxs,g=rx,o=' $< /usr/bin/$@

$(OBJ)/libfunsync.so:	CFLAGS += -shared
$(OBJ)/libfunsync.so:	misc/libfunsync.c

$(OBJ)/ssh_force_lp.so:	CFLAGS += -shared
$(OBJ)/ssh_force_lp.so:	misc/ssh_force_lp.c

$(OBJ)/unsymlink.so:	CFLAGS += -shared
$(OBJ)/unsymlink.so:	LDLIBS += $(DL_LDLIBS)
$(OBJ)/unsymlink.so:	misc/unsymlink.c

$(OBJ)/libwcwidth.so:	CFLAGS += -shared -fPIC \
				-Dmk_wcwidth=wcwidth -Dmk_wcswidth=wcswidth
$(OBJ)/libwcwidth.so:	thirdparty/wcwidth.c

$(OBJ)/misc_util.o:	misc/util.c misc/util.h

$(OBJ)/strnatcmp.o:	thirdparty/strnatcmp.c

$(OBJ)/ac-wait:		LDLIBS += -ludev
$(OBJ)/ac-wait:		misc/ac-wait.c

$(OBJ)/args:		misc/args.c

$(OBJ)/gettime:		LDLIBS += -lrt
$(OBJ)/gettime:		misc/gettime.c

$(OBJ)/hex:		misc/hex.c

$(OBJ)/k5userok:	CFLAGS += $(KRB_CFLAGS)
$(OBJ)/k5userok:	LDLIBS += $(KRB_LDLIBS)
$(OBJ)/k5userok:	kerberos/k5userok.c

$(OBJ)/mkpasswd:	LDLIBS += $(CRYPT_LDLIBS)
$(OBJ)/mkpasswd:	misc/mkpasswd.c

$(OBJ)/natsort:		thirdparty/natsort.c $(OBJ)/strnatcmp.o

$(OBJ)/peekvc:		thirdparty/peekvc.c

$(OBJ)/pklist:		CFLAGS += $(KRB_CFLAGS)
$(OBJ)/pklist:		LDLIBS += $(KRB_LDLIBS)
$(OBJ)/pklist:		kerberos/pklist.c

$(OBJ)/pause:		misc/pause.c

$(OBJ)/proctool:	misc/proctool.c $(OBJ)/misc_util.o

$(OBJ)/showsigmask:	CFLAGS += -I$(OBJ)
$(OBJ)/showsigmask:	misc/showsigmask.c

$(OBJ)/spawn:		misc/spawn.c $(OBJ)/misc_util.o

$(OBJ)/statx:		misc/statx.c

$(OBJ)/strtool:		misc/strtool.c

$(OBJ)/tapchown:	misc/tapchown.c

$(OBJ)/unescape:	misc/unescape.c

$(OBJ)/unhex:		misc/unhex.c

$(OBJ)/urlencode:	misc/urlencode.c

$(OBJ)/writevt:		thirdparty/writevt.c

$(OBJ)/zlib:		LDLIBS += -lz
$(OBJ)/zlib:		thirdparty/zpipe.c

$(OBJ)/newrdt:		LDLIBS += -lresolv
$(OBJ)/newrdt:		misc/rdt.c

$(OBJ)/gl-mem:		CFLAGS += $(shell pkg-config --cflags x11 epoxy)
$(OBJ)/gl-mem:		LDLIBS += $(shell pkg-config --libs x11 epoxy)
$(OBJ)/gl-mem:		misc/gl-mem.c

$(OBJ)/emergency-su:	LDLIBS += $(CRYPT_LDLIBS)
$(OBJ)/emergency-su:	misc/emergency-su.c
