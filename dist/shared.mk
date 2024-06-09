comma	:= ,
empty	:=
space	:= $(empty) $(empty)
UNAME	:= $(shell uname)
HNAME	:= $(shell hostname | sed 's/[.].*//')
DIST	?= dist
OBJ	:= obj/host.$(HNAME)

# cflags

ifeq ($(origin CC),default)
CC := gcc
endif

CFLAGS := -pipe -Wall -O1 -g
LDFLAGS := -Wl,--as-needed

include $(DIST)/guess.mk

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

dummy := $(DIST)/empty.c
arg    = $(firstword $(patsubst $(dummy),,$(1)))
args   = $(strip $(patsubst $(dummy),,$(1)))

$(OBJ)/%.h: dist/configure
	$(verbose_echo) "  GEN   $(notdir $@)"
	$(verbose_hide) dist/configure $@

$(OBJ)/%.o: $(dummy)
	$(verbose_echo) "  CC    $(notdir $@) ($(call arg,$^))"
	$(verbose_hide) $(COMPILE.c) $(OUTPUT_OPTION) $(call arg,$^)

$(OBJ)/%: $(dummy)
	$(verbose_echo) "  CCLD  $(notdir $@) ($(call args,$^))"
	$(verbose_hide) $(LINK.c) $(call args,$^) $(LOADLIBES) $(LDLIBS) -o $@

# generic targets

default:

$(OBJ)/.prepare:
	$(verbose_hide) $(DIST)/prepare
	$(verbose_hide) touch $@

# A trick to make every other job depend on $(OBJ)
-include $(OBJ)/.prepare

clean:
	rm -rf obj/arch.* obj/dist.* obj/host.*

mrproper:
	git clean -fdX
	git checkout -f obj

.PHONY: default prepare clean mrproper
