/* $Id: peekvc.c 80 2005-08-10 19:07:11Z lennart $ */

/***
  This file is part of peekvc.
  
  peekvc is free software; you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  peekvc is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with peekvc; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
  02110-1301, USA.
***/

#include <errno.h>
#include <string.h>
#include <limits.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <getopt.h>

#define ESC "\x1B"
#define ANSI_RESET ESC"[0;22;49;39m"

static void set_vc_attr(unsigned c) {

    static const int ansi_table[] = { 0, 4, 2, 6, 1, 5, 3, 7 };

    printf(ESC"[%i;%i;%im", c & 8 ? 1 : 0, ansi_table[((c >> 4) & 7)] + 40, ansi_table[(c & 7)] + 30);
}

static int peek_vc(int fd, unsigned char *ret_lines) {
    int ret = -1;
    unsigned char lines, cols, caret_x, caret_y, x, y, *ln = NULL;

    errno = 0;

    if (lseek(fd, 0, SEEK_SET) == (off_t) -1) {
        fprintf(stderr, "llseek(): %s\n", strerror(errno));
        goto finish;
    }
    
    if (read(fd, &lines, 1) != 1 ||
        read(fd, &cols, 1) != 1 ||
        read(fd, &caret_x, 1) != 1 ||
        read(fd, &caret_y, 1) != 1) {
        fprintf(stderr, "read(): %s\n", errno != 0 ? strerror(errno) : "EOF");
        goto finish;
    }

    if (ret_lines)
        *ret_lines = lines;
    
    if (!(ln = malloc(cols*2))) {
        fprintf(stderr, "malloc(): %s\n", strerror(errno));
        goto finish;
    }

    for (y = 0; y < lines; y++) {
        int prev_a = -1;
        
        errno = 0;

        if (read(fd, ln, cols*2) != cols*2) {
            fprintf(stderr, "read(): %s\n", errno != 0 ? strerror(errno) : "EOF");
            goto finish;
        }

        for (x = 0; x < cols; x++) {
            char c = ((char*) ln)[x*2];
            unsigned char a = ln[x*2+1];

            if (prev_a != (int) a) {
                set_vc_attr(a);
                prev_a = a;
            }
            
            putchar(c >= 32 && c < 127 ? c : '.');
        }
        
        fputs(ANSI_RESET"\n", stdout);
    }

    ret = 0;

finish:

    if (ln)
        free(ln);

    return ret;
}

static void help(const char *argv0) {
    char *l;

    if ((l = strrchr(argv0, '/')))
        argv0 = (const char*) l + 1;

    fprintf(stderr,
            "%s [-h]\n"
            "%s [-l] [VCNR]\n\n"
            "   -h Show this help\n"
            "   -l Run in loop\n", argv0, argv0);
}

int main(int argc, char *argv[]) {
    char fn[PATH_MAX];
    int fd = -1;
    int ret = 1, tty_id;
    int ch, run_loop = 0;

    while ((ch = getopt(argc, argv, "lh")) >= 0) {
        
        switch (ch) {
            case 'l':
                run_loop = 1;
                break;

            case 'h':
                help(argv[0]);
                ret = 0;
                goto finish;

            default:
                help(argv[0]);
                goto finish;
        }
    }

    tty_id = 0;

    if (optind < argc)
        tty_id = atoi(argv[optind]);

    if (tty_id < 0) {
        fprintf(stderr, "Invalid VC number %i", tty_id);
        goto finish;
    }
            
    snprintf(fn, sizeof(fn), "/dev/vcsa%i", tty_id);

    if ((fd = open(fn, O_RDONLY)) < 0) {
        fprintf(stderr, "open(%s) failed: %s\n", fn, strerror(errno));
        goto finish;
    }

    if (run_loop) {
        for (;;) {
            unsigned char lines;
            
            if (peek_vc(fd, &lines) < 0)
                goto finish;
            
            usleep(500000);
            
            printf(ESC"[%uA", lines);
        }
    } else {
        
        if (peek_vc(fd, NULL) < 0)
            goto finish;
    }
    
    ret = 0;

finish:


    if (fd >= 0)
        close(fd);

    fputs(ANSI_RESET, stdout);
    
    return ret;
}
