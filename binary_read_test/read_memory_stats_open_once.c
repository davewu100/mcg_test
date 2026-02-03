/*
 * Same pattern as read_memory_stats_ks_open_once.c but reads
 * memory.stat and memory.numa_stat (no .ks) for comparison.
 * Open once, then 1M times each: lseek(0) + read().
 * Compile: gcc -O2 -o read_memory_stats_open_once read_memory_stats_open_once.c
 * Run: time ./read_memory_stats_open_once
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>

#define N        1000000
#define BUF_SIZE 4096
#define DEFAULT_CGPATH "/sys/fs/cgroup"

int main(void)
{
	const char *cgpath = getenv("CGPATH");
	if (!cgpath)
		cgpath = DEFAULT_CGPATH;
	char path_stat[256], path_numa[256];
	char buf[BUF_SIZE];
	int fd_stat, fd_numa;
	int i;
	ssize_t n;

	snprintf(path_stat, sizeof(path_stat), "%s/memory.stat", cgpath);
	snprintf(path_numa, sizeof(path_numa), "%s/memory.numa_stat", cgpath);

	fd_stat = open(path_stat, O_RDONLY);
	if (fd_stat < 0) {
		perror(path_stat);
		return 1;
	}
	fd_numa = open(path_numa, O_RDONLY);
	if (fd_numa < 0) {
		perror(path_numa);
		close(fd_stat);
		return 1;
	}

	for (i = 0; i < N; i++) {
		if (lseek(fd_stat, 0, SEEK_SET) < 0) {
			perror("lseek stat");
			break;
		}
		n = read(fd_stat, buf, sizeof(buf));
		(void)n;

		if (lseek(fd_numa, 0, SEEK_SET) < 0) {
			perror("lseek numa");
			break;
		}
		n = read(fd_numa, buf, sizeof(buf));
		(void)n;
	}

	close(fd_stat);
	close(fd_numa);
	return 0;
}
