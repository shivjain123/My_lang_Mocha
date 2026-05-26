#include <stdio.h>
#include <setjmp.h>

jmp_buf buf;

void thrower() {
    printf("before longjmp\n");
    longjmp(buf, 1);
    printf("after longjmp (should never print)\n");
}

int main() {
    if (setjmp(buf) == 0) {
        printf("try path\n");
        thrower();
    } else {
        printf("rescue path\n");
    }
    printf("after\n");
    return 0;
}