#define _GNU_SOURCE
#include <stdio.h>
#include <err.h>
#include <errno.h>
#include <epoxy/gl.h>
#include <epoxy/glx.h>
#include <getopt.h>

static int usage() {
	printf("Usage: %s [-s]\n", program_invocation_name);
	return 2;
}

int get_mem_ATI(void) {
	int meminfo[4];

	glGetIntegerv(GL_TEXTURE_FREE_MEMORY_ATI, meminfo);
	return meminfo[0];
}

int get_mem_NVX(void) {
	int mem;

	glGetIntegerv(GL_GPU_MEMORY_INFO_DEDICATED_VIDMEM_NVX, &mem);
	return mem;
}

int get_mem_MESA(void) {
	unsigned int mem;

	glXQueryCurrentRendererIntegerMESA(GLX_RENDERER_VIDEO_MEMORY_MESA, &mem);
	return mem;
}

bool has_gl_extension(const char *name)
{
	bool r = epoxy_has_gl_extension(name);
	printf("%c %s\n", r ? '+' : '-', name);
	return r;
}

bool has_glx_extension(Display *dpy, int screen, const char *name)
{
	bool r = epoxy_has_glx_extension(dpy, screen, name);
	printf("%c %s\n", r ? '+' : '-', name);
	return r;
}

void
setup_glx_context(Display *dpy)
{
	GLint vis_attrib[] = { GLX_RGBA, GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, None };
	XSetWindowAttributes win_attrib;
	XVisualInfo *vis;
	Window win, root;
	GLXContext glc;

	root = RootWindow(dpy, DefaultScreen(dpy));

	vis = epoxy_glXChooseVisual(dpy, DefaultScreen(dpy), vis_attrib);
	if (!vis)
		errx(1, "epoxy_glXChooseVisual failed");

	win_attrib = (XSetWindowAttributes) {
		.colormap = XCreateColormap(dpy, root, vis->visual, AllocNone),
	};

	win = XCreateWindow(dpy, root,
			0, 0, 10, 10, 0,
			vis->depth,
			InputOutput,
			vis->visual,
			CWColormap,
			&win_attrib);

	glc = epoxy_glXCreateContext(dpy, vis, False, True);
	if (!glc)
		errx(1, "epoxy_glXCreateContext failed");

	epoxy_glXMakeCurrent(dpy, win, glc);
}

int main(int argc, char *argv[]) {
	int opt;
	bool verbose = true;
	Display *dpy;
	int scr;

	while ((opt = getopt(argc, argv, "sv")) != -1) {
		switch (opt) {
		case 's':
			verbose = false;
			break;
		case 'v':
			verbose = true;
			break;
		default:
			return usage();
		}
	}

	dpy = XOpenDisplay(NULL);
	if (!dpy)
		errx(1, "XOpenDisplay failed");

	scr = DefaultScreen(dpy);

	setup_glx_context(dpy);

	if (verbose) {
		printf("GL vendor = %s\n", epoxy_glGetString(GL_VENDOR));
		printf("GL renderer = %s\n", epoxy_glGetString(GL_RENDERER));
		printf("GL version = %s\n", epoxy_glGetString(GL_VERSION));

		if (has_gl_extension("GL_ATI_meminfo")) {
			printf("GL_TEXTURE_FREE_MEMORY_ATI = %d kB\n", get_mem_ATI());
		}
		if (has_gl_extension("GL_NVX_gpu_memory_info")) {
			printf("GL_GPU_MEMORY_INFO_DEDICATED_VIDMEM_NVX = %d kB\n", get_mem_NVX());
		}
		if (has_glx_extension(dpy, scr, "GLX_MESA_query_renderer")) {
			printf("GLX_RENDERER_VIDEO_MEMORY_MESA = %d MB\n", get_mem_MESA());
		}
	} else {
		if (epoxy_has_gl_extension("GL_ATI_meminfo")) {
			printf("%d\n", get_mem_ATI() / 1024);
		}
		else if (epoxy_has_gl_extension("GL_NVX_gpu_memory_info")) {
			printf("%d\n", get_mem_NVX() / 1024);
		}
		else if (epoxy_has_glx_extension(dpy, scr, "GLX_MESA_query_renderer")) {
			printf("%d\n", get_mem_MESA());
		}
	}

	return 0;
}
