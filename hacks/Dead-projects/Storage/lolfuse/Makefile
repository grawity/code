CC = clang

default: test

fuse: CFLAGS += $(shell pkg-config --cflags fuse)
fuse: LDLIBS += $(shell pkg-config --libs fuse)

test: fuse
	fusermount -u foo || true
	./fuse foo -o allow_other
