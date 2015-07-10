CRYPT_LDLIBS := -lcrypt
DL_LDLIBS := -ldl
KRB_LDLIBS := -lkrb5 -lcom_err

ifeq ($(UNAME),Linux)
	OSFLAGS := -DHAVE_LINUX
endif

ifeq ($(UNAME),FreeBSD)
	OSFLAGS := -DHAVE_FREEBSD
	DL_LDLIBS := $(empty)
endif

ifeq ($(UNAME),GNU)
	OSFLAGS := -DHAVE_HURD
endif

ifeq ($(UNAME),NetBSD)
	OSFLAGS := -DHAVE_NETBSD
endif

ifeq ($(UNAME),OpenBSD)
	OSFLAGS := -DHAVE_OPENBSD
	CRYPT_LDLIBS := $(empty)
	DL_LDLIBS := $(empty)
	KRB_LDLIBS := -lkrb5 -lcom_err -lcrypto
endif

ifeq ($(UNAME),CYGWIN_NT-5.1)
	OSFLAGS := -DHAVE_CYGWIN
endif

ifeq ($(UNAME),SunOS)
	OSFLAGS := -DHAVE_SOLARIS
	KRB_LDLIBS := -lkrb5
endif
