#define _GNU_SOURCE
#include <dlfcn.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdio.h>
#include <unistd.h> /* sleep */


/* make_dark(): set _GTK_THEME_VARIANT on the given window */

void make_dark(Display *display, Window w)
{
	Atom property = XInternAtom(display, "_GTK_THEME_VARIANT", False);
	Atom type = XInternAtom(display, "UTF8_STRING", False);
	int format = 8;
	int mode = PropModeReplace;
	char *data = "dark";
	int nelements = sizeof("dark")-1;

	fprintf(stderr, "setting variant to '%s'\n", data);

	XChangeProperty(display, w, property, type, format, mode,
			(const unsigned char *) data, nelements);
}

/* overlay XSetWMName() */

void XSetWMName(Display *display, Window w, XTextProperty *text_prop)
{
	static void (*real_XSetWMName)(Display *display, Window w,
					XTextProperty *text_prop);
	
	if (!real_XSetWMName)
		real_XSetWMName = dlsym(RTLD_NEXT, "XSetWMName");
	real_XSetWMName(display, w, text_prop);

	fprintf(stderr, "XSetWMName(0x%lx, '%s') = void\n", w, text_prop->value);
}

void XSetWMClientMachine(Display *display, Window w, XTextProperty *text_prop)
{
	static void (*real_XSetWMClientMachine)(Display *display, Window w,
					XTextProperty *text_prop);
	
	if (!real_XSetWMClientMachine)
		real_XSetWMClientMachine = dlsym(RTLD_NEXT, "XSetWMClientMachine");
	real_XSetWMClientMachine(display, w, text_prop);

	fprintf(stderr, "XSetWMClientMachine(0x%lx, '%s') = void\n", w, text_prop->value);
	make_dark(display, w);
}

/* overlay XSetTextProperty */

void XSetTextProperty(Display *display, Window w, XTextProperty *text_prop, Atom property)
{
	static void (*real_XSetTextProperty)(Display *display, Window w,
						XTextProperty *text_prop,
						Atom property);
	const char *name;

	if (!real_XSetTextProperty)
		real_XSetTextProperty = dlsym(RTLD_NEXT, "XSetTextProperty");
	real_XSetTextProperty(display, w, text_prop, property);

	name = XGetAtomName(display, property);
	fprintf(stderr, "XSetTextProperty(0x%lx, '%s', '%s') = void\n",
		w, text_prop->value, XGetAtomName(display, property));
}

/* overlay XSetClassHint() */

Status XSetClassHint(Display *display, Window w, XClassHint *class_hints)
{
	static Status (*real_XSetClassHint)(Display *display, Window w,
					    XClassHint *class_hints);
	Status r;

	if (!real_XSetClassHint)
		real_XSetClassHint = dlsym(RTLD_NEXT, "XSetClassHint");
	r = real_XSetClassHint(display, w, class_hints);

	fprintf(stderr, "XSetClassHint(0x%lx, {name '%s', class '%s'}\n",
		w, class_hints->res_name, class_hints->res_class);

	make_dark(display, w);

	return r;
}

void *SDL_CreateWindow(const char *title, int x, int y, int w, int h, int flags)
{
	static void *(*real_SDL_CreateWindow)(const char *title, int x, int y,
					      int w, int h, int flags);
	void *r;

	if (!real_SDL_CreateWindow)
		real_SDL_CreateWindow = dlsym(RTLD_NEXT, "SDL_CreateWindow");
	r = real_SDL_CreateWindow(title, x, y, w, h, flags);

	fprintf(stderr, "SDL_CreateWindow('%s', %d, %d, %d, %d, 0x%x)\n",
		title, x, y, w, h, flags);

	return r;
}

/* XSetWMNormalHints */
/* XSetWMSizeHints */
/* XSetWMClientMachine */
/* XSetWMProperties */
/* XSetTextProperty */
/* getMaxVideoRamSetting */
