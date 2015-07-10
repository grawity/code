# vim: ft=make

DIST := $(HOME)/code/dist

include $(DIST)/shared.mk

override CFLAGS += -I$(DIST)/../misc

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

# compile targets

BASIC_BINS := mkpasswd proctool strtool
LINUX_BINS := globalenv libfunlink.so libfunsync.so libglobalenv.so showsigmask tapchown
MISC_BINS  := xor xors xorf zlib
JUNK_BINS  := ac-wait subreaper

.PHONY: all basic linux misc

basic: $(addprefix $(OBJ)/,$(BASIC_BINS))
krb:   $(addprefix $(OBJ)/,$(KRB_BINS))
linux: $(addprefix $(OBJ)/,$(LINUX_BINS))
misc:  $(addprefix $(OBJ)/,$(MISC_BINS))
junk:  $(addprefix $(OBJ)/,$(JUNK_BINS))

all: basic krb misc
ifeq ($(UNAME),Linux)
all: linux junk
endif

emergency-sulogin: $(OBJ)/emergency-sulogin
	sudo install -o 'root' -g 'wheel' -m 'u=rxs,g=rx,o=' $< /usr/bin/$@

# libraries

$(OBJ)/libfunlink.so:	CFLAGS += -shared -fPIC
$(OBJ)/libfunlink.so:	LDLIBS += $(DL_LDLIBS)
$(OBJ)/libfunlink.so:	system/libfunlink.c

$(OBJ)/libfunsync.so:	CFLAGS += -shared
$(OBJ)/libfunsync.so:	system/libfunsync.c

$(OBJ)/libglobalenv.so:	CFLAGS += -shared -fPIC
$(OBJ)/libglobalenv.so:	LDLIBS += -lkeyutils
$(OBJ)/libglobalenv.so:	system/libglobalenv.c

# executables

$(OBJ)/ac-wait:		LDLIBS += -ludev
$(OBJ)/ac-wait:		system/ac-wait.c
$(OBJ)/entropy:		LDLIBS += -lm
$(OBJ)/entropy:		security/entropy.c
$(OBJ)/globalenv:	LDLIBS += -lkeyutils
$(OBJ)/globalenv:	system/globalenv.c $(OBJ)/misc_util.o
$(OBJ)/mkpasswd:	LDLIBS += $(CRYPT_LDLIBS)
$(OBJ)/mkpasswd:	security/mkpasswd.c
$(OBJ)/proctool:	system/proctool.c $(OBJ)/misc_util.o
$(OBJ)/showsigmask:	system/showsigmask.c
$(OBJ)/strtool:		misc/strtool.c
$(OBJ)/subreaper:	system/subreaper.c
$(OBJ)/tapchown:	net/tapchown.c
$(OBJ)/xor:		misc/xor.c
$(OBJ)/xorf:		misc/xorf.c
$(OBJ)/xors:		misc/xors.c
