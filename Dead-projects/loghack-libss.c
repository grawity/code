#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <ss/ss.h>
#include <string.h>
#include <stdlib.h>

static void *(*next_ss_set_prompt)(int, char *);

static int *(*next_ss_create_invocation)(const char *, const char *, void *,
					ss_request_table *, int *);

static void wrap_init(void) __attribute__((constructor));

static char *mangle_prompt(const char *);

static char *prompt_color = NULL;

void ss_set_prompt(int sci_idx, char *new_prompt)
{
	if (next_ss_set_prompt) {
		char *p = mangle_prompt(new_prompt);
		next_ss_set_prompt(sci_idx, p);
	}
}

int ss_create_invocation(const char *subsystem_name, const char *version_string,
void *info_ptr, ss_request_table *request_table_ptr, int *code_ptr)
{
	if (next_ss_create_invocation) {
		char *p = mangle_prompt(subsystem_name);
		next_ss_create_invocation(p, version_string, info_ptr,
					request_table_ptr, code_ptr);
	}
}

char *mangle_prompt(const char *prompt)
{
	if (!prompt_color)
		return (char *) prompt;

	char *p = malloc(1 + strlen(prompt_color) + 1 + strlen(prompt) + 5 + 1);
	strcpy(p, "\001");
	strcat(p, prompt_color);
	strcat(p, "\002");
	strcat(p, prompt);
	strcat(p, "\001\033[m\002");
	return p;
}

static void wrap_init(void)
{
	prompt_color = getenv("SS_PROMPT_FORMAT");

	next_ss_create_invocation = dlsym(RTLD_NEXT, "ss_create_invocation");
	next_ss_set_prompt = dlsym(RTLD_NEXT, "ss_set_prompt");
}
