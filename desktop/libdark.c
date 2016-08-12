#define _GNU_SOURCE
#include <dlfcn.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdio.h>

/* make_dark(): set _GTK_THEME_VARIANT on the given window */

void make_dark(Display *display, Window w)
{
	Atom property = XInternAtom(display, "_GTK_THEME_VARIANT", False);
	Atom type = XInternAtom(display, "UTF8_STRING", False);
	int format = 8;
	int mode = PropModeReplace;
	char *data = "dark";
	int nelements = sizeof("dark")-1;

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
