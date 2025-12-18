#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// Light-touch read: small pread at offset 0 to trigger rstat refresh
static ssize_t touch_small(int fd, size_t min_bytes) {
    if (min_bytes == 0) min_bytes = 1;   // clamp to 1 byte
    char buf[32];                        // tiny buffer; keeps copy-to-user minimal
    if (min_bytes > sizeof(buf)) min_bytes = sizeof(buf);
    return pread(fd, buf, min_bytes, 0);
}

// Print full file once (for initial inspection)
static void dump_fd(const char *label, int fd) {
    char buf[65536];                     // large enough for memory.numa_stat/memory.stat
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
    // USAGE: ./readstats N [SLEEP_US] [PATH]
    // - N: number of light-touch iterations
    // - SLEEP_US: optional microseconds between iterations (default 0)
    // - PATH: optional cgroup dir (default: /sys/fs/cgroup/a)
    if (argc < 2 || argc > 4) {
        fprintf(stderr, "USAGE: %s N [SLEEP_US] [CGROUP_PATH]\n", argv[0]);
        return 1;
    }
    long long n = atoll(argv[1]);
    int sleep_us = (argc >= 3) ? atoi(argv[2]) : 0;
    const char *cgpath = (argc == 4) ? argv[3] : "/sys/fs/cgroup/a";

    char p_cgstat[512], p_memstat[512], p_numa[512], p_memcur[512];
    snprintf(p_cgstat, sizeof(p_cgstat), "%s/cgroup.stat", cgpath);
    snprintf(p_memstat, sizeof(p_memstat), "%s/memory.stat", cgpath);
    snprintf(p_numa,   sizeof(p_numa),   "%s/memory.numa_stat", cgpath);
    snprintf(p_memcur, sizeof(p_memcur), "%s/memory.current", cgpath);

    int f_cgstat = open(p_cgstat, O_RDONLY);
    int f_memst  = open(p_memstat, O_RDONLY);
    int f_numa   = open(p_numa,   O_RDONLY);
    int f_memcur = open(p_memcur, O_RDONLY);
    if (f_cgstat < 0 || f_memst < 0 || f_numa < 0 || f_memcur < 0) {
        perror("open");
        return 1;
    }

    // One-shot prints for visibility
    dump_fd("cgroup.stat",        f_cgstat);
    dump_fd("memory.stat",        f_memst);
    dump_fd("memory.numa_stat",   f_numa);
    dump_fd("memory.current",     f_memcur);

    // Loop: light-touch ONLY memory.current (cheap path)
    for (long long i = 0; i < n; i++) {
        if (touch_small(f_memcur, 1) < 0) {   // 1 byte is enough to trigger
            perror("pread(memory.current)");
            break;
        }
        if (sleep_us > 0) usleep(sleep_us);
    }

    close(f_cgstat);
    close(f_memst);
    close(f_numa);
    close(f_memcur);
    return 0;
}