#define _GNU_SOURCE
#include <sys/types.h>
#include <dlfcn.h>
#include <keyutils.h>
#include <stdio.h>
#include <stdlib.h>

key_serial_t def_keyring = KEY_SPEC_USER_KEYRING;

char value[4096];

char *getenv(const char *name) {
	static char *(*real_getenv)(const char *);
	int r;
	char *desc;
	key_serial_t key_id;

	r = asprintf(&desc, "env:%s", name);
	if (r >= 0) {
		key_id = keyctl_search(def_keyring, "user", desc, 0);
		if (key_id) {
			r = keyctl_read(key_id, value, sizeof(value));
			if (r >= 0)
				return value;
		}
		free(desc);
	}

	if (!real_getenv)
		real_getenv = dlsym(RTLD_NEXT, "getenv");
	return real_getenv(name);
}
