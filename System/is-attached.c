#include <stdio.h>
#include <utmpx.h>

typedef int Set;

bool set_new(Set **hp) {
	**hp = hcreate(500);
}

bool set_contains(Set *h, const char *n) {
	return hsearch(h->
}

bool set_add(Set *h, const char *n) {
}

bool set_remove(Set *h, const char *n) {
	TODO;
}

bool re_match(...) {
	TODO;
}

int main(void) {
	Set *ttys;
	struct utmp *ut;

	set_new(&ttys);

	while (ut = getutent()) {
		if (ut->ut_type != USER_PROCESS)
			continue;
		if (!set_contains(ttys, ut->ut_line))
			continue;
		if (re_match(...))
			set_remove(ttys, ut->ut_line);
	}
}
