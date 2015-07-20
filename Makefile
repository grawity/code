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

BASIC_BINS := args gettime mkpasswd natsort pause silentcat spawn unescape libwcwidth.so
KRB_BINS   := k5userok pklist
MISC_BINS  := logwipe writevt zlib

.PHONY: all basic krb misc pklist

basic: $(addprefix $(OBJ)/,$(BASIC_BINS))
krb:   $(addprefix $(OBJ)/,$(KRB_BINS))
misc:  $(addprefix $(OBJ)/,$(MISC_BINS))

all: basic krb misc

pklist: $(OBJ)/pklist

emergency-sulogin: $(OBJ)/emergency-sulogin
	sudo install -o 'root' -g 'wheel' -m 'u=rxs,g=rx,o=' $< /usr/bin/$@

# libraries

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

# executables

$(OBJ)/args:		misc/args.c
$(OBJ)/gettime:		LDLIBS += -lrt
$(OBJ)/gettime:		misc/gettime.c
$(OBJ)/codeset:		misc/codeset.c
$(OBJ)/k5userok:	LDLIBS += $(KRB_LDLIBS)
$(OBJ)/k5userok:	kerberos/k5userok.c
$(OBJ)/logwipe:		thirdparty/logwipe.c
$(OBJ)/mkpasswd:	LDLIBS += $(CRYPT_LDLIBS)
$(OBJ)/mkpasswd:	security/mkpasswd.c
$(OBJ)/natsort:		thirdparty/natsort.c $(OBJ)/strnatcmp.o
$(OBJ)/pklist:		LDLIBS += $(KRB_LDLIBS)
$(OBJ)/pklist:		kerberos/pklist.c
$(OBJ)/pause:		system/pause.c
$(OBJ)/silentcat:	misc/silentcat.c
$(OBJ)/spawn:		system/spawn.c $(OBJ)/misc_util.o
$(OBJ)/unescape:	misc/unescape.c
$(OBJ)/writevt:		thirdparty/writevt.c
$(OBJ)/zlib:		LDLIBS += -lz
$(OBJ)/zlib:		thirdparty/zpipe.c

$(OBJ)/emergency-sulogin:	LDLIBS += $(CRYPT_LDLIBS) -static
$(OBJ)/emergency-sulogin:	security/emergency-sulogin.c
