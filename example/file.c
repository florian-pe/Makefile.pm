#include <stdlib.h>
#include <stdbool.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include "system.h"

bool file_size(char *path, off_t *size) {
    struct stat statbuf;

    if (stat(path, &statbuf) == 0) {
        *size = statbuf.st_size;
        return 1;
    }
    else {
        return 0;
    }
}

char *file_read(char *path) {
    char *string;
    off_t size;
    ssize_t bytes_read;
    int fd;

    if (!file_size(path, &size)) {
        return NULL;
    }

    if (!sys_open(path, O_RDONLY, &fd)) {
        return NULL;
    }
    
    string = malloc(size + 1);
    if (string == NULL) {
        close(fd);
        return NULL;
    }

    bytes_read = read(fd, string, size);
    if (bytes_read == -1) {
        close(fd);
        free(string);
        return NULL;
    }
    else if (bytes_read != size) {
        close(fd);
        free(string);
        return NULL;
    }

    if (close(fd) == -1) {
        free(string);
        return NULL;
    }
    
    string[size] = '\0';
    return string;
}


