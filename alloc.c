/*
 * Tiny helper that allocates and touches M bytes, then sleeps so memory stays charged to the cgroup.
 * It accepts size like 80M/1G and a duration.*/
#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static size_t parse_size(const char *s) {
    char *end;
    double v = strtod(s, &end);
    if (end == s || v <= 0) return 0;
    if (*end == 'g' || *end == 'G') return (size_t)(v * 1024 * 1024 * 1024);
    if (*end == 'm' || *end == 'M') return (size_t)(v * 1024 * 1024);
    if (*end == 'k' || *end == 'K') return (size_t)(v * 1024);
    return (size_t)v; // bytes
}

int main(int argc, char **argv) {
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "USAGE: %s SIZE [SECONDS]\n", argv[0]);
        return 1;
    }
    size_t sz = parse_size(argv[1]);
    if (sz == 0) {
        fprintf(stderr, "Invalid size: %s\n", argv[1]);
        return 1;
    }
    int secs = (argc == 3) ? atoi(argv[2]) : 60;

    // Allocate and touch every page so it is actually charged.
    char *p = (char*)malloc(sz);
    if (!p) {
        fprintf(stderr, "malloc(%zu) failed: %s\n", sz, strerror(errno));
        return 1;
    }
    const size_t step = 4096;
    for (size_t i = 0; i < sz; i += step) {
        p[i] = (char)(i & 0xFF);
    }

    // Keep resident for observation window.
    sleep(secs);

    // Optionally touch again before exit.
    for (size_t i = 0; i < sz; i += step) {
        p[i] ^= 0x1;
    }
    free(p);
    return 0;
}
