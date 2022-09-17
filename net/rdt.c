#define _GNU_SOURCE

#include <err.h>
#include <errno.h>
#include <search.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

struct set {
	struct hsearch_data htab;
};

typedef struct set Set;

Set *set_new() {
	Set *this;
	int r;

	this = calloc(1, sizeof(Set));
	if (!this)
		abort();

	r = hcreate_r(4096, &this->htab);
	if (r == 0)
		err(1, "could not alloc htable");

	return this;
}

void set_free(Set **thisp) {
	if (!*thisp)
		return;

	hdestroy_r(&(*thisp)->htab);

	*thisp = NULL;
}

void set_add(Set *this, char *value) {
	ENTRY entry, *found;
	int r;

	entry = (ENTRY) { .key = value, .data = NULL };
	r = hsearch_r(entry, ENTER, &found, &this->htab);
	if (!r)
		err(1, "hsearch failed");
}

bool set_find(Set *this, char *value) {
	ENTRY entry, *found;
	int r;

	entry = (ENTRY) { .key = value, .data = NULL };
	r = hsearch_r(entry, FIND, &found, &this->htab);
	if (!r) {
		if (errno == ESRCH)
			return false;
		else
			err(1, "hsearch failed");
	}
	return true;
}

void rdt_nest(char *arg, int depth, Set *skip, Set *visited) {
	int i;
	char **results;

	for (i = 0; i < depth; i++)
		printf("   ");
	printf("%s = ", arg);
	fflush(stdout);

	//results = resolve(arg);
	
	printf("(none)\n");

	/*
    print("   " * depth + color(addr) + " = ", end="", flush=True)

    addresses = resolve(addr)
    addresses.sort() # XXX

    if addresses:
        print(", ".join(addresses))
        for nextaddr in addresses:
            if nextaddr in visited or nextaddr in skip:
                continue
            visited.add(nextaddr)
            rdt(nextaddr, depth+1, skip|{*addresses}, visited)
    else:
        print(color("(none)"))
        */
}

void rdt(char *arg) {
	Set *skip;
	Set *visited;

	skip = set_new();
	visited = set_new();

	rdt_nest(arg, 0, skip, visited);

	set_free(&skip);
	set_free(&visited);
}

int main(int argc, char *argv[]) {
	int i;

	for (i = 1; i < argc; i++) {
		rdt(argv[i]);
	}

	return 0;
}
