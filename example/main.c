#include <stdio.h>
#include <stdlib.h>
#include "file.h"

int main (int argc, char **argv) {
    char *file_string;

    if (argc < 2) {
        exit(1);
    }

    file_string = file_read(argv[1]);
    if (!file_string) {
        fprintf(stderr, "can't read file '%s'\n", argv[1]);
        exit(1);
    }

    printf("%s", file_string);

    return 0;
}

