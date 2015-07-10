#define _GNU_SOURCE
#include <dlfcn.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdio.h>

void make_dark(Display *display, Window w)
{
	Atom property = XInternAtom(display, "_GTK_THEME_VARIANT", False);
	Atom type = XInternAtom(display, "UTF8_STRING", False);
	int format = 8;
	int mode = PropModeReplace;
	char *data = "dark";
	int nelements = sizeof("dark")-1;

	XChangeProperty(display, w, property, type, format, mode, data, nelements);
}

void XSetWMName(Display *display, Window w, XTextProperty *text_prop)
{
	static void (*real_XSetWMName)(Display *display, Window w,
					XTextProperty *text_prop);
	
	if (!real_XSetWMName)
		real_XSetWMName = dlsym(RTLD_NEXT, "XSetWMName");
	real_XSetWMName(display, w, text_prop);

	fprintf(stderr, "XSetWMName(0x%x, '%s') = void\n", w, text_prop->value);
}

XSetClassHint(Display *display, Window w, XClassHint *class_hints)
{
	static (*real_XSetClassHint)(Display *display, Window w, XClassHint *class_hints);
	char *name, *class;
	int r;

	if (!real_XSetClassHint)
		real_XSetClassHint = dlsym(RTLD_NEXT, "XSetClassHint");
	r = real_XSetClassHint(display, w, class_hints);

	name = class_hints->res_name;
	class = class_hints->res_class;

	fprintf(stderr, "XSetClassHint(0x%x, {name '%s', class '%s'}\n",
		w, class_hints->res_name, class_hints->res_class);

	make_dark(display, w);

	return r;
}
