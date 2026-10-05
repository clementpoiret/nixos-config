#include <dlfcn.h>
#include <stdio.h>

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s MESA_LIBRARY\n", argv[0]);
        return 2;
    }

    void *driver = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (driver == NULL) {
        fprintf(stderr, "Cannot load Mesa: %s\n", dlerror());
        return 1;
    }

    dlclose(driver);
    return 0;
}
