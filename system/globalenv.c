#define _GNU_SOURCE
#include <sys/types.h>
#include <stdio.h>
#include <keyutils.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <util.h>
#include <err.h>

char *arg0;

key_serial_t def_keyring = KEY_SPEC_USER_KEYRING;

static int usage() {
	printf("Usage: %s <program> [<args>...]\n", arg0);
	printf("       %s -c <shellcommand>\n", arg0);
	printf("       %s [-e]\n", arg0);
	printf("       %s -s <env>...\n", arg0);
	printf("       %s -x\n", arg0);
	printf("\n");
	printf("Options:\n");
	printf("  -c    run given command through the shell\n");
	printf("  -e    shell-escape environment values when printing\n");
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
	int r;

	if (name[0] == '+') {
		name++;
		if (strchr(name, '=')) {
			warnx("invalid variable name '%s'", name);
			return;
		}
		value = getenv(name);
	} else if (name[0] == '-') {
		name++;
		if (strchr(name, '=')) {
			warnx("invalid variable name '%s'", name);
			return;
		}
		value = NULL;
	} else {
		value = strchr(name, '=');
		if (value)
			*value++ = '\0';
	}

	if (!*name) {
		warnx("empty variable name not allowed");
		return;
	}

	asprintf(&desc, "env:%s", name);

	if (value && *value) {
		id = add_key("user", desc, (void *)value,
		             strlen(value), def_keyring);
	} else {
		id = keyctl_search(def_keyring, "user", desc, 0);
		if (id) {
			r = keyctl_unlink(id, def_keyring);
			if (r < 0) {
				warn("could not remove variable '%s' (%u)",
					name, id);
			}
		}
	}
}

int clear_env() {
	struct Env *envlistp, *envp;
	int r;

	envlistp = Env_enum();

	Env_each(envp, envlistp) {
		r = keyctl_unlink(envp->id, def_keyring);
		if (r < 0) {
			warn("could not remove variable '%s' (%u)",
				envp->name, envp->id);
			continue;
		}
	}

	Env_free(envlistp);

	return 0;
}

void import_env(void) {
	struct Env *envlistp, *envp;
	int r;

	envlistp = Env_enum();

	Env_each(envp, envlistp) {
		_cleanup_free_ char *value = NULL;

		r = keyctl_read_alloc(envp->id, (void**)&value);
		if (r < 0) {
			warn("could not read variable '%s' (%u)",
				envp->name, envp->id);
			continue;
		}

		setenv(envp->name, value, true);
	}

	Env_free(envlistp);
}

int print_env(bool escape) {
	struct Env *envlistp, *envp;
	int r;

	envlistp = Env_enum();

	Env_each(envp, envlistp) {
		_cleanup_free_ char *value = NULL;
		_cleanup_free_ char *escaped = NULL;

		r = keyctl_read_alloc(envp->id, (void**)&value);
		if (r < 0) {
			warn("could not read variable '%s' (%u)",
				envp->name, envp->id);
			continue;
		}

		if (escape) {
			escaped = shell_escape(value);
			printf("%s=%s\n", envp->name, escaped);
		} else {
			printf("%s=%s\n", envp->name, value);
		}
	}

	Env_free(envlistp);

	return 0;
}

int execvp_with_env(int argc, char *argv[]) {
	int r;

	import_env();

	r = execvp(argv[0], argv);
	if (r < 0) {
		warn("could not run '%s'", argv[0]);
		return 1;
	}

	return 0;
}

int system_with_env(char *arg) {
	int r;

	import_env();

	r = system(arg);
	if (r < 0) {
		warn("could not run '%s'", arg);
		return 1;
	}

	return 0;
}

int main(int argc, char *argv[]) {
	int opt, mode = 0;
	bool escape = false;

	arg0 = argv[0];

	while ((opt = getopt(argc, argv, "+cesx")) != -1) {
		switch (opt) {
		case 'c':
		case 's':
		case 'x':
			if (mode) {
				warnx("too many actions given");
				return usage();
			}
			mode = opt;
			break;
		case 'e':
			escape = true;
			break;
		default:
			return usage();
		}
	}

	argc -= optind;
	argv += optind;

	switch (mode) {
	case 's': /* set from command line */
		while (*argv)
			update_env(*argv++);
		return 0;
	case 'x': /* remove all */
		if (argc == 0)
			return clear_env();
		else
			return usage();
	case 'c': /* run shell command */
		if (argc == 1)
			return system_with_env(argv[0]);
		else
			return usage();
	default: /* run argv */
		if (argc)
			return execvp_with_env(argc, argv);
		else
			return print_env(escape);
	}
}
