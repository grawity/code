comma := ,
empty :=
space := $(empty) $(empty)

UNAME := $(shell uname)
OBJ   := $(shell dist/prepare -o)

# cflags

ifeq ($(origin CC),default)
CC := gcc
endif

CFLAGS := -pipe -Wall -O1 -g
LDFLAGS := -Wl,--as-needed

include dist/guess.mk

override CFLAGS += $(OSFLAGS) $(cflags)

# output

ifeq ($(V),1)
	verbose_hide := $(empty)
	verbose_echo := @:
else
	verbose_hide := @
	verbose_echo := @echo
endif

# compile recipes

$(OBJ)/%.o: $(dummy)
	$(verbose_echo) "  CC    $(notdir $@) ($(call arg,$^))"
	$(verbose_hide) $(COMPILE.c) $(OUTPUT_OPTION) $(call arg,$^)

$(OBJ)/%: $(dummy)
	$(verbose_echo) "  CCLD  $(notdir $@) ($(call args,$^))"
	$(verbose_hide) $(LINK.c) $(call args,$^) $(LOADLIBES) $(LDLIBS) -o $@

# generic targets

default:

clean:
	rm -rf obj/arch.* obj/dist.* obj/host.*

mrproper:
	git clean -fdX
	git checkout -f obj

.PHONY: default clean mrproper
