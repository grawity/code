#if 0
libdate.so: libdate.c
	$(LINK.c) -shared -fPIC $^ -ldl -o $@

define source
#endif

#define _GNU_SOURCE
#include <dlfcn.h>
#include <langinfo.h>

char *date_fmt = "%Y-%m-%d %H:%M:%S %z";

char *nl_langinfo(nl_item item) {
	static char *(*real_nl_langinfo)(nl_item item);

	if (item == _DATE_FMT)
		return date_fmt;

	if (!real_nl_langinfo)
		real_nl_langinfo = dlsym(RTLD_NEXT, "nl_langinfo");

	return real_nl_langinfo(item);
}

#if 0
endef
#endif
