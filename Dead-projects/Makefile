loghack-libss.so: CFLAGS := -I"$(HOME)/e2fsprogs/lib" -fPIC -shared
loghack-libss.so: LDLIBS := -ldl
loghack-libss.so: loghack-libss.c
	$(CC) $(CFLAGS) -o $@ $< $(LDLIBS)

loghack-glib.so: CFLAGS += $(shell pkg-config --cflags glib-2.0) -fPIC -shared
loghack-glib.so: LDLIBS += $(shell pkg-config --libs   glib-2.0)
loghack-glib.so: loghack-glib.c
	$(CC) $(CFLAGS) -o $@ $< $(LDLIBS)
