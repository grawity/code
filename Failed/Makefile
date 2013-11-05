libss-hack.so: CFLAGS := -fPIC -shared
libss-hack.so: LDLIBS := -ldl
libss-hack.so: libss-hack.c
	$(CC) -I"$(HOME)/e2fsprogs/lib" -fPIC -shared -o $@ $(LDLIBS) $<

