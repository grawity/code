#define _GNU_SOURCE
#include <sys/types.h>
#include <stdio.h>
#include <keyutils.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <util.h>

char *arg0;

key_serial_t def_keyring = KEY_SPEC_USER_KEYRING;

static int usage() {
	printf("Usage: %s <program> [<args>...]\n", arg0);
	printf("       %s -c <shellcommand>\n", arg0);
	printf("       %s -s <env>...\n", arg0);
	printf("       %s -x\n", arg0);
	printf("\n");
	printf("Options:\n");
	printf("  -c    run given command through the shell\n");
	printf("  -s    update global environment with given values\n");
	printf("  -x    remove all values from the global environment\n");
	printf("\n");
	printf("If <program> is not given, the global environment variables are printed.\n");
	printf("\n");
	printf("<env> may be 'KEY=value' to set a variable; 'KEY=' or 'KEY' to remove it;\n");
	printf("or '+KEY' to import from current environment (adding or removing). Empty\n");
	printf("values are not allowed.\n");
	return 2;
}

struct Env {
	key_serial_t id;
	char *name;
	struct Env *next;
};

struct Env * Env_enum(void) {
	key_serial_t *ringp, *keyp;
	size_t ringz;
	struct Env *env = NULL, *lastenv = NULL;

	ringz = keyctl_read_alloc(def_keyring, (void**)&ringp);

	for (keyp = ringp;
	     ringz > 0;
	     ringz -= sizeof(key_serial_t), ++keyp)
	{
		_cleanup_free_ char *rdesc = NULL;
		char *desc;

		keyctl_describe_alloc(*keyp, &rdesc);
		if (strncmp(rdesc, "user;", 5))
			continue;

		desc = strrchr(rdesc, ';') + 1;
		if (strncmp(desc, "env:", 4))
			continue;

		lastenv = env;
		env = malloc(sizeof(struct Env));
		env->id = *keyp;
		env->name = strdup(desc + 4);
		env->next = lastenv;
	}

	free(ringp);

	return env;
}

#define Env_each(var, lvar) for (var = lvar; var; var = var->next)

void Env_free(struct Env *ptr) {
	struct Env *next;

	while (ptr) {
		next = ptr->next;
		free(ptr->name);
		free(ptr);
		ptr = next;
	}
}

void update_env(char *name) {
	char *value;
	_cleanup_free_ char *desc = NULL;
	key_serial_t id;

	if (name[0] == '+') {
		name++;
		if (strchr(name, '=')) {
			fprintf(stderr, "%s: Invalid variable name '%s'\n",
				arg0, name);
			return;
		}
		value = getenv(name);
	} else {
		value = strchr(name, '=');
		if (value)
			*value++ = '\0';
	}

	if (!*name) {
		fprintf(stderr, "%s: Empty variable name not allowed\n", arg0);
		return;
	}

	asprintf(&desc, "env:%s", name);

	if (value && *value) {
		id = add_key("user", desc, (void *)value,
		             strlen(value), def_keyring);
	} else {
		id = keyctl_search(def_keyring, "user", desc, 0);

		if (id)
			keyctl_unlink(id, def_keyring);
	}
}

int clear_env() {
	struct Env *envlistp, *envp;

	envlistp = Env_enum();

	Env_each(envp, envlistp) {
		keyctl_unlink(envp->id, def_keyring);
	}

	Env_free(envlistp);

	return 0;
}

void import_env(void) {
	struct Env *envlistp, *envp;

	envlistp = Env_enum();

	Env_each(envp, envlistp) {
		_cleanup_free_ char *value = NULL;

		keyctl_read_alloc(envp->id, (void**)&value);
		setenv(envp->name, value, true);
	}

	Env_free(envlistp);
}

int print_env(void) {
	struct Env *envlistp, *envp;

	envlistp = Env_enum();

	Env_each(envp, envlistp) {
		_cleanup_free_ char *value = NULL;

		keyctl_read_alloc(envp->id, (void**)&value);
		printf("%s=%s\n", envp->name, value);
	}

	Env_free(envlistp);

	return 0;
}

int execvp_with_env(int argc, char *argv[]) {
	int r;

	import_env();

	r = execvp(argv[0], argv);
	if (r < 0) {
		fprintf(stderr, "%s: Could not run '%s': %m\n",
			arg0, argv[0]);
		return 1;
	}

	return 0;
}

int system_with_env(char *arg) {
	int r;

	import_env();

	r = system(arg);
	if (r < 0) {
		fprintf(stderr, "%s: Could not run '%s': %m\n",
			arg0, arg);
		return 1;
	}

	return 0;
}

int main(int argc, char *argv[]) {
	int opt, mode = 0;

	arg0 = argv[0];

	while ((opt = getopt(argc, argv, "+csx")) != -1) {
		switch (opt) {
		case 'c':
		case 's':
		case 'x':
			if (mode)
				return usage();
			mode = opt;
			break;
		default:
			return usage();
		}
	}

	argc -= optind;
	argv += optind;

	if (mode == 's') {
		while (*argv)
			update_env(*argv++);
		return 0;
	} else if (mode == 'x') {
		if (argc == 0)
			return clear_env();
		else
			return usage();
	} else if (mode == 'c') {
		if (argc == 1)
			return system_with_env(argv[0]);
		else
			return usage();
	} else {
		if (argc)
			return execvp_with_env(argc, argv);
		else
			return print_env();
	}
}
