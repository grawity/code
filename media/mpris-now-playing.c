#if 0
pkg = glib-2.0 gio-2.0
app = nowplaying

CFLAGS  = $(shell pkg-config --cflags $(pkg)) -x c
LDFLAGS = $(shell pkg-config --libs $(pkg))

$(app): $(MAKEFILE_LIST)

define source
#endif

#include <glib.h>
#include <glib/gprintf.h>
#include <gio/gio.h>

int main(void) {
	GError *error = NULL;
	GDBusConnection *bus;
	GVariant *result, *props;
	gchar **artists = NULL, *artist = NULL, *title = NULL;

	bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
	if (!bus) {
		g_warning("Failed to connect to session bus: %s", error->message);
		g_error_free(error);
		return 1;
	}

	result = g_dbus_connection_call_sync(bus,
					// bus name
					"org.mpris.MediaPlayer2.mpd",
					// object path
					"/org/mpris/MediaPlayer2",
					// interface
					"org.freedesktop.DBus.Properties",
					// method name
					"Get",
					// argument
					g_variant_new("(ss)",
						// property interface
						"org.mpris.MediaPlayer2.Player",
						// property name
						"Metadata"),
					// return value
					G_VARIANT_TYPE("(v)"),
					// flags
					G_DBUS_CALL_FLAGS_NONE,
					-1,
					NULL,
					&error);

	if (!result) {
		g_warning("Failed to call Get: %s\n", error->message);
		g_error_free(error);
		return 1;
	}

	g_variant_get(result, "(v)", &props);
	g_variant_lookup(props, "xesam:artist", "^a&s", &artists);
	g_variant_lookup(props, "xesam:title", "&s", &title);

	if (artists)
		artist = g_strjoinv(", ", artists);
	else
		artist = "(Unknown Artist)";

	if (!title)
		title = "(Unknown Song)";

	g_printf("%s – %s\n", artist, title);

	g_free(artist);

	return 0;
}

#if 0
endef
#endif
