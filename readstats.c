/* Fixes the path case (a vs A) and focuses on memory stats.
 * It still demonstrates reading multiple stat files if you want parity with your original.
 * It prints the first snapshot and then loops N iterations.*/
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

static void dump_fd(const char *label, int fd) {
    char buf[8192];
    ssize_t n;
    lseek(fd, 0, SEEK_SET);
    n = read(fd, buf, sizeof(buf)-1);
    if (n < 0) { perror("read"); return; }
    buf[n] = '\0';
    printf("=== %s ===\n%s", label, buf);
}

int main(int argc, char *argv[])
{
    if (argc != 2) {
        printf("USAGE: %s N\n", argv[0]);
        return 1;
    }
    int n = atoi(argv[1]);
    const char *base = "/sys/fs/cgroup/a";

    int f_stat   = open("/sys/fs/cgroup/a/cgroup.stat", O_RDONLY);
    int f_memst  = open("/sys/fs/cgroup/a/memory.stat", O_RDONLY);
    int f_memcur = open("/sys/fs/cgroup/a/memory.current", O_RDONLY);
    if (f_stat < 0 || f_memst < 0 || f_memcur < 0) {
        perror("open");
        return 1;
    }

    for (int i = 0; i < n; i++) {
        if (i == 0) {
            dump_fd("cgroup.stat", f_stat);
            dump_fd("memory.stat", f_memst);
            dump_fd("memory.current", f_memcur);
        } else {
            // Read memory.stat in loop to test cache
            char buf[8192];
            lseek(f_memst, 0, SEEK_SET);
            ssize_t m = read(f_memst, buf, sizeof(buf)-1);
            if (m > 0) {
                buf[m] = '\0';
                // Print a compact line each loop
                // printf("loop %d: memory.stat read %zu bytes\n", i, m);
            }
            // Also read memory.current
            lseek(f_memcur, 0, SEEK_SET);
            m = read(f_memcur, buf, sizeof(buf)-1);
            if (m > 0) {
                buf[m] = '\0';
                // Print a compact line each loop
                // printf("loop %d: memory.current=%s", i, buf);
            }
        }
        // usleep(200 * 1000); // 200ms between iterations
    }

    close(f_stat);
    close(f_memst);
    close(f_memcur);
    return 0;
}
