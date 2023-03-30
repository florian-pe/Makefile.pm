#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdbool.h>


bool sys_open(char *pathname, int flags, int *fd_output) {
    int fd = open(pathname, flags);
    if (fd == -1) {
        return 0;
    }
    *fd_output = fd;
    return 1;
}








