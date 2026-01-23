/* Read binary format memory.stat_bin and memory.numa_stat_bin files
 * Similar structure to readstats.c but reads binary interface
 * Format matches kernel's memcg_stat_bin_header and memcg_stat_bin_entry
 */
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>
#include <endian.h>
#include <errno.h>

#define MEMCG_STAT_BIN_MAGIC	0x4D454D43	/* "MEMC" */
#define MEMCG_STAT_BIN_VERSION	1

struct memcg_stat_bin_header {
	uint32_t magic;
	uint8_t version;
	uint16_t stat_count;
	uint16_t event_count;
	uint16_t numa_stat_count;
} __attribute__((packed));

struct memcg_stat_bin_entry {
	uint16_t idx;
	uint64_t value;
} __attribute__((packed));

static uint16_t read_u16_le(int fd) {
	uint16_t val;
	if (read(fd, &val, 2) != 2) {
		perror("read u16");
		exit(1);
	}
	return le16toh(val);
}

static uint32_t read_u32_le(int fd) {
	uint32_t val;
	if (read(fd, &val, 4) != 4) {
		perror("read u32");
		exit(1);
	}
	return le32toh(val);
}

static uint64_t read_u64_le(int fd) {
	uint64_t val;
	if (read(fd, &val, 8) != 8) {
		perror("read u64");
		exit(1);
	}
	return le64toh(val);
}

static uint8_t read_u8(int fd) {
	uint8_t val;
	if (read(fd, &val, 1) != 1) {
		perror("read u8");
		exit(1);
	}
	return val;
}

static void read_binary_stat(const char *label, int fd, int iteration) {
	struct memcg_stat_bin_header hdr;
	struct memcg_stat_bin_entry entry;
	int i;

	/* Seek to beginning */
	if (lseek(fd, 0, SEEK_SET) < 0) {
		perror("lseek");
		return;
	}

	/* Read header */
	if (read(fd, &hdr, sizeof(hdr)) != sizeof(hdr)) {
		perror("read header");
		return;
	}
	/* Convert from little-endian */
	hdr.magic = le32toh(hdr.magic);
	hdr.stat_count = le16toh(hdr.stat_count);
	hdr.event_count = le16toh(hdr.event_count);
	hdr.numa_stat_count = le16toh(hdr.numa_stat_count);

	/* Verify magic */
	if (hdr.magic != MEMCG_STAT_BIN_MAGIC) {
		fprintf(stderr, "Error: Invalid magic 0x%08x, expected 0x%08x\n",
			hdr.magic, MEMCG_STAT_BIN_MAGIC);
		return;
	}

	if (iteration == 0) {
		printf("=== %s ===\n", label);
		printf("Magic: 0x%08x\n", hdr.magic);
		printf("Version: %u\n", hdr.version);
		printf("Stat count: %u\n", hdr.stat_count);
		printf("Event count: %u\n", hdr.event_count);
		printf("NUMA stat count: %u\n", hdr.numa_stat_count);
		printf("\n");

		/* Read and display stats */
		printf("Stats:\n");
		for (i = 0; i < hdr.stat_count; i++) {
			entry.idx = read_u16_le(fd);
			entry.value = read_u64_le(fd);
			printf("  idx=%u value=%llu\n", entry.idx, (unsigned long long)entry.value);
		}

		/* Read and display events */
		if (hdr.event_count > 0) {
			printf("\nEvents:\n");
			for (i = 0; i < hdr.event_count; i++) {
				entry.idx = read_u16_le(fd);
				entry.value = read_u64_le(fd);
				printf("  idx=%u value=%llu\n", entry.idx, (unsigned long long)entry.value);
			}
		}
		printf("\n");
	} else {
		/* Just read through the data without printing (for performance testing) */
		for (i = 0; i < hdr.stat_count; i++) {
			read_u16_le(fd);  /* idx */
			read_u64_le(fd); /* value */
		}
		for (i = 0; i < hdr.event_count; i++) {
			read_u16_le(fd);  /* idx */
			read_u64_le(fd); /* value */
		}
	}
}

int main(int argc, char *argv[])
{
	if (argc != 2) {
		printf("USAGE: %s N\n", argv[0]);
		return 1;
	}
	int n = atoi(argv[1]);
	const char *base = "/sys/fs/cgroup/a";

	int f_stat_bin = open("/sys/fs/cgroup/a/memory.stat_bin", O_RDONLY);
	int f_numa_stat_bin = open("/sys/fs/cgroup/a/memory.numa_stat_bin", O_RDONLY);
	if (f_stat_bin < 0 || f_numa_stat_bin < 0) {
		perror("open");
		return 1;
	}

	for (int i = 0; i < n; i++) {
		if (i == 0) {
			read_binary_stat("memory.stat_bin", f_stat_bin, i);
			read_binary_stat("memory.numa_stat_bin", f_numa_stat_bin, i);
		} else {
			/* Read memory.stat_bin and memory.numa_stat_bin in loop to test cache */
			read_binary_stat("memory.stat_bin", f_stat_bin, i);
			read_binary_stat("memory.numa_stat_bin", f_numa_stat_bin, i);
		}
		// usleep(200 * 1000); // 200ms between iterations
	}

	close(f_stat_bin);
	close(f_numa_stat_bin);
	return 0;
}

