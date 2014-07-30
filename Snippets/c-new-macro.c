#include <stdlib.h>
#include <stdio.h>

#define new(type, ...)                 \
({                                     \
    type *_var = malloc(sizeof(type)); \
    *_var = (type){ __VA_ARGS__ };     \
    _var;                              \
})

struct foo {
    int x, y;
};

int main(void)
{
    struct foo *foo;

    foo = new(struct foo, 0);
    printf("x: %d\n", foo->x);
    printf("y: %d\n", foo->y);

    foo = new(struct foo, .y = 6);
    printf("x: %d\n", foo->x);
    printf("y: %d\n", foo->y);

    foo = new(struct foo, .x = 9);
    printf("x: %d\n", foo->x);
    printf("y: %d\n", foo->y);
}
