/* I think that's called a free-list allocator? Or something. */

#include <stdlib.h>
#include <stdio.h>

struct {
	size_t slice;
	void *free;
	void *start;
	void *end;
} arena;

void* foo_alloc() {
	void *ptr = arena.free ?: arena.start;
	if (ptr >= arena.end) return NULL;
	arena.free = *(void **)ptr ?: ptr + arena.slice;
	return ptr;
}

void foo_free(void *ptr) {
	*(void **)ptr = arena.free;
	arena.free = ptr;
}

int main(void) {
	arena.slice = 16;
	arena.start = calloc(1024, arena.slice);
	arena.end = arena.start + (1024 * arena.slice);

	printf("arena starts at %p\n", arena.start);

	char *a = foo_alloc(); printf("a @ %p\n", a);
	char *b = foo_alloc(); printf("b @ %p\n", b);
	char *c = foo_alloc(); printf("c @ %p\n", c);
	void *d = foo_alloc(); printf("d @ %p\n", d);
	void *e = foo_alloc(); printf("e @ %p\n", e);
	foo_free(b); printf("b freed, arena.free = %p\n", arena.free);
	foo_free(d); printf("d freed, arena.free = %p\n", arena.free);
	foo_free(c); printf("c freed, arena.free = %p\n", arena.free);
	b = foo_alloc(); printf("b @ %p\n", b);
	b = foo_alloc(); printf("b @ %p\n", b);
	b = foo_alloc(); printf("b @ %p\n", b);
	b = foo_alloc(); printf("b @ %p\n", b);

	return 0;
}
