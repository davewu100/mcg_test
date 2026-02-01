/*
 * Full-field read of memory.stat.ks and memory.numa_stat.ks via BTF + cache.
 * Sets 16-field filter (vmstats.state[0]..vmstats.state[15]) then open-once
 * + 1M lseek+read on each file. Compile and run:
 *   gcc -O2 -o read_memory_stats_ks_full_open_once read_memory_stats_ks_full_open_once.c
 *   sudo ./read_memory_stats_ks_full_open_once
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>

#define N         1000000
#define CGPATH    "/sys/fs/cgroup"
#define BUF_SIZE  4096
#define KS_MAX_FIELDS 16

static const char *full_filter(void)
{
	static char buf[1024];
	size_t n = 0;
	int i;

	for (i = 0; i < KS_MAX_FIELDS; i++) {
		n += (size_t)snprintf(buf + n, sizeof(buf) - n,
			"%svmstats.state[%d]", i ? "," : "", i);
		if (n >= sizeof(buf)) break;
	}
	return buf;
}

int main(void)
{
	char path_stat[256], path_numa[256];
	char buf[BUF_SIZE];
	const char *filter = full_filter();
	int fd_stat, fd_numa;
	FILE *fp;
	int i;
	ssize_t n;

	snprintf(path_stat, sizeof(path_stat), "%s/memory.stat.ks", CGPATH);
	snprintf(path_numa, sizeof(path_numa), "%s/memory.numa_stat.ks", CGPATH);

	/* Set 16-field filter on both .ks files (requires write = root) */
	fp = fopen(path_stat, "w");
	if (fp) {
		fprintf(fp, "%s", filter);
		fclose(fp);
	}
	fp = fopen(path_numa, "w");
	if (fp) {
		fprintf(fp, "%s", filter);
		fclose(fp);
	}

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
