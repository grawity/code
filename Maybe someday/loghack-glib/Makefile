PKG     = glib-2.0

CFLAGS += -fPIC

CFLAGS += $(shell pkg-config --cflags $(PKG))
LDLIBS += $(shell pkg-config --libs   $(PKG))

loghack-glib.so: loghack-glib.c
	gcc -shared $(CFLAGS) -o $@ $< $(LDLIBS)
