#if 0
pkg = glib-2.0 gio-2.0 upower-glib
app = upowermon

CFLAGS = $(shell pkg-config --cflags $(pkg)) -x c
LDLIBS = $(shell pkg-config --libs $(pkg))

$(app): $(MAKEFILE_LIST)

define source
#endif

#include <glib.h>
#include <upower.h>

int main(void) {
	GError *error = NULL;
	UpClient *client = NULL;
	UpDevice **devices;

	client = up_client_new();

	devices = up_client_enumerate_devices(client);
}

#if 0
endef
#endif
