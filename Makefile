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

BASIC_BINS := ac-wait entropy proctool strtool subreaper xor xors xorf
LINUX_BINS := globalenv libfunlink.so libfunsync.so libglobalenv.so showsigmask tapchown

.PHONY: all basic linux

basic: $(addprefix $(OBJ)/,$(BASIC_BINS))
linux: $(addprefix $(OBJ)/,$(LINUX_BINS))

all: basic
ifeq ($(UNAME),Linux)
all: linux
endif

# libraries

$(OBJ)/libdark.so:	CFLAGS += $(pkg-config x11 --cflags) -shared -fPIC
$(OBJ)/libdark.so:	LDLIBS += $(pkg-config x11 --libs)
$(OBJ)/libdark.so:	desktop/libdark.c

$(OBJ)/libfunlink.so:	CFLAGS += -shared -fPIC
$(OBJ)/libfunlink.so:	LDLIBS += $(DL_LDLIBS)
$(OBJ)/libfunlink.so:	system/libfunlink.c

$(OBJ)/libfunsync.so:	CFLAGS += -shared
$(OBJ)/libfunsync.so:	system/libfunsync.c

$(OBJ)/libglobalenv.so:	CFLAGS += -shared -fPIC
$(OBJ)/libglobalenv.so:	LDLIBS += -lkeyutils
$(OBJ)/libglobalenv.so:	system/libglobalenv.c

# objects

$(OBJ)/misc_util.o:	$(DIST)/../misc/util.c $(DIST)/../misc/util.h

# executables

$(OBJ)/ac-wait:		LDLIBS += -ludev
$(OBJ)/ac-wait:		system/ac-wait.c

$(OBJ)/entropy:		LDLIBS += -lm
$(OBJ)/entropy:		security/entropy.c

$(OBJ)/gl-mem:		CFLAGS += $(shell pkg-config x11 epoxy --cflags)
$(OBJ)/gl-mem:		LDLIBS += $(shell pkg-config x11 epoxy --libs)
$(OBJ)/gl-mem:		desktop/gl-mem.c

$(OBJ)/globalenv:	LDLIBS += -lkeyutils
$(OBJ)/globalenv:	system/globalenv.c $(OBJ)/misc_util.o

$(OBJ)/proctool:	system/proctool.c $(OBJ)/misc_util.o

$(OBJ)/showsigmask:	system/showsigmask.c

$(OBJ)/strtool:		misc/strtool.c

$(OBJ)/subreaper:	system/subreaper.c

$(OBJ)/tapchown:	net/tapchown.c

$(OBJ)/xor:		misc/xor.c

$(OBJ)/xorf:		misc/xorf.c

$(OBJ)/xors:		misc/xors.c
