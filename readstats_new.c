#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// Light-touch read: small pread at offset 0 to trigger rstat refresh
static ssize_t touch_small(int fd) {
    char buf[256];  // small buffer to minimize copy-to-user cost
    return pread(fd, buf, sizeof(buf), 0);
}

// Print full file once (for initial inspection)
static void dump_fd(const char *label, int fd) {
    char buf[65536];  // large enough for memory.numa_stat on typical systems
    ssize_t n;

    if (lseek(fd, 0, SEEK_SET) < 0) {
        perror("lseek");
        return;
    }
    n = read(fd, buf, sizeof(buf) - 1);
    if (n < 0) {
        perror("read");
        return;
    }
    buf[n] = '\0';
    printf("=== %s ===\n%s", label, buf);
}

int main(int argc, char *argv[]) {
    // USAGE: ./readstats N [SLEEP_US]
    // - N: number of light-touch iterations
    // - SLEEP_US: optional microseconds between iterations (default 0)
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "USAGE: %s N [SLEEP_US]\n", argv[0]);
        return 1;
    }
    long long n = atoll(argv[1]);
    int sleep_us = (argc == 3) ? atoi(argv[2]) : 0;

    // Adjust the cgroup path as needed
    const char *p_cgstat  = "/sys/fs/cgroup/a/cgroup.stat";
    const char *p_memstat = "/sys/fs/cgroup/a/memory.stat";
    const char *p_numa    = "/sys/fs/cgroup/a/memory.numa_stat";

    int f_cgstat = open(p_cgstat,  O_RDONLY);
    int f_memst  = open(p_memstat, O_RDONLY);
    int f_numa   = open(p_numa,    O_RDONLY);
    if (f_cgstat < 0 || f_memst < 0 || f_numa < 0) {
        perror("open");
        return 1;
    }

    // Print once for visibility
    dump_fd("cgroup.stat",        f_cgstat);
    dump_fd("memory.stat",        f_memst);
    dump_fd("memory.numa_stat",   f_numa);

    // Loop: light-touch refresh for memory.* only (do NOT touch cgroup.stat)
    for (long long i = 0; i < n; i++) {
        if (touch_small(f_memst) < 0) { perror("pread(memory.stat)"); break; }
        if (touch_small(f_numa)  < 0) { perror("pread(memory.numa_stat)"); break; }

        if (sleep_us > 0) usleep(sleep_us);
    }

    close(f_cgstat);
    close(f_memst);
    close(f_numa);
    return 0;
}
