/* Focused on memory stats with configurable millisecond interval and optional continuous mode.
 * Usage:
 *   readstats_interval N [interval_ms]
 *   N > 0: run N iterations
 *   N = 0: run continuously until interrupted (Ctrl-C)
 *   interval_ms > 0 (default 1000 ms)
 */
#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <time.h>

static volatile sig_atomic_t g_stop = 0;
static void on_sigint(int signo) { (void)signo; g_stop = 1; }

static void dump_fd(const char *label, int fd) {
    char buf[8192];
    ssize_t n;
    lseek(fd, 0, SEEK_SET);
    n = read(fd, buf, sizeof(buf)-1);
    if (n < 0) { perror("read"); return; }
    buf[n] = '\0';
    printf("=== %s ===\n%s", label, buf);
    fflush(stdout);
}

static int parse_nonneg_int(const char *s, int *out) {
    char *end = NULL;
    errno = 0;
    long v = strtol(s, &end, 10);
    if (errno != 0 || end == s || *end != '\0' || v < 0 || v > INT_MAX) {
        return -1;
    }
    *out = (int)v;
    return 0;
}

static int parse_positive_int(const char *s, int *out) {
    char *end = NULL;
    errno = 0;
    long v = strtol(s, &end, 10);
    if (errno != 0 || end == s || *end != '\0' || v <= 0 || v > INT_MAX) {
        return -1;
    }
    *out = (int)v;
    return 0;
}

static void sleep_ms(int interval_ms) {
    if (interval_ms <= 0) return;
    struct timespec ts;
    ts.tv_sec = interval_ms / 1000;
    ts.tv_nsec = (long)(interval_ms % 1000) * 1000000L;

    while (nanosleep(&ts, &ts) == -1 && errno == EINTR) {
        if (g_stop) break; // interrupted by signal; exit early if stopping
    }
}

int main(int argc, char *argv[])
{
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "USAGE: %s N [interval_ms]\n", argv[0]);
        fprintf(stderr, "  N>0: run N iterations; N=0: run continuously\n");
        return 1;
    }

    int n;
    if (parse_nonneg_int(argv[1], &n) != 0) {
        fprintf(stderr, "Invalid N: %s (must be >= 0)\n", argv[1]);
        return 1;
    }

    int interval_ms = 1000; // default 1000 ms
    if (argc == 3) {
        if (parse_positive_int(argv[2], &interval_ms) != 0) {
            fprintf(stderr, "Invalid interval_ms: %s (must be > 0)\n", argv[2]);
            return 1;
        }
    }

    // Graceful stop on Ctrl-C/TERM
    struct sigaction sa = {0};
    sa.sa_handler = on_sigint;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    int f_stat   = open("/sys/fs/cgroup/a/cgroup.stat", O_RDONLY);
    int f_memst  = open("/sys/fs/cgroup/a/memory.stat", O_RDONLY);
    int f_memcur = open("/sys/fs/cgroup/a/memory.current", O_RDONLY);
    if (f_stat < 0 || f_memst < 0 || f_memcur < 0) {
        perror("open");
        return 1;
    }

    // One iteration body
    // Note: printing only the first snapshot; follow-up iterations can be made compact.
    // Uncomment below printf to show periodic memory.current.
    for (int i = 0; (n == 0) ? !g_stop : (i < n && !g_stop); i++) {
        if (i == 0) {
            dump_fd("cgroup.stat", f_stat);
            dump_fd("memory.stat", f_memst);
            dump_fd("memory.current", f_memcur);
        } else {
            char buf[128];
            lseek(f_memcur, 0, SEEK_SET);
            ssize_t m = read(f_memcur, buf, sizeof(buf)-1);
            if (m > 0) {
                buf[m] = '\0';
                // printf("loop %d: memory.current=%s", i, buf);
                // fflush(stdout);
            }
        }

        // Sleep between iterations (skip after last when finite)
        if ((n == 0 || i != n - 1) && !g_stop) {
            sleep_ms(interval_ms);
        }
    }

    close(f_stat);
    close(f_memst);
    close(f_memcur);
    return 0;
}
