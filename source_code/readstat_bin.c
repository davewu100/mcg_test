/* Read and parse binary format memory.stat_bin file
 * Format: [Header][Entries...]
 * Header: magic(4) version(1) reserved(3) num_stats(2) num_events(2)
 * Entry: name_len(1) name(name_len) value(8)
 */
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>
#include <endian.h>
#include <errno.h>

#define MAGIC 0x5454534D  /* "MSTT" */

struct header {
	uint32_t magic;
	uint8_t version;
	uint8_t reserved[3];
	uint16_t num_stats;
	uint16_t num_events;
} __attribute__((packed));

static uint8_t read_u8(int fd) {
	uint8_t val;
	if (read(fd, &val, 1) != 1) {
		perror("read u8");
		exit(1);
	}
	return val;
}

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

static void read_string(int fd, char *buf, size_t len) {
	if (read(fd, buf, len) != (ssize_t)len) {
		perror("read string");
		exit(1);
	}
	buf[len] = '\0';
}

static const char *format_bytes(uint64_t bytes) {
	static char buf[64];
	const char *units[] = {"B", "KB", "MB", "GB", "TB", "PB"};
	double size = bytes;
	int unit_idx = 0;

	while (size >= 1024.0 && unit_idx < 5) {
		size /= 1024.0;
		unit_idx++;
	}

	if (unit_idx == 0) {
		snprintf(buf, sizeof(buf), "%llu %s", (unsigned long long)bytes, units[unit_idx]);
	} else {
		snprintf(buf, sizeof(buf), "%.2f %s", size, units[unit_idx]);
	}
	return buf;
}

static int is_bytes_stat(const char *name) {
	return strstr(name, "anon") || strstr(name, "file") ||
	       strstr(name, "kernel") || strstr(name, "slab") ||
	       strstr(name, "shmem") || strstr(name, "vmalloc") ||
	       strstr(name, "percpu") || strstr(name, "sock") ||
	       strstr(name, "zswap") || strstr(name, "hugetlb");
}

int main(int argc, char *argv[])
{
	const char *file_path = argc > 1 ? argv[1] : "/sys/fs/cgroup/a/memory.stat_bin";
	int fd;
	struct header hdr;
	char name_buf[256];
	uint64_t value;
	uint64_t anon = 0, file = 0, kernel = 0;
	int i;

	fd = open(file_path, O_RDONLY);
	if (fd < 0) {
		perror("open");
		return 1;
	}

	/* Read header */
	hdr.magic = read_u32_le(fd);
	hdr.version = read_u8(fd);
	read(fd, hdr.reserved, 3);
	hdr.num_stats = read_u16_le(fd);
	hdr.num_events = read_u16_le(fd);

	/* Verify magic */
	if (hdr.magic != MAGIC) {
		fprintf(stderr, "Error: Invalid magic 0x%08x, expected 0x%08x\n",
			hdr.magic, MAGIC);
		close(fd);
		return 1;
	}

	printf("=== Memory Stat Binary Format ===\n");
	printf("Magic: 0x%08x\n", hdr.magic);
	printf("Version: %u\n", hdr.version);
	printf("Number of stats: %u\n", hdr.num_stats);
	printf("Number of events: %u\n", hdr.num_events);
	printf("\n");

	printf("=== Statistics ===\n");
	for (i = 0; i < hdr.num_stats; i++) {
		uint8_t name_len = read_u8(fd);
		if (name_len > 255)
			name_len = 255;
		read_string(fd, name_buf, name_len);
		value = read_u64_le(fd);

		/* Track key stats */
		if (strcmp(name_buf, "anon") == 0)
			anon = value;
		else if (strcmp(name_buf, "file") == 0)
			file = value;
		else if (strcmp(name_buf, "kernel") == 0)
			kernel = value;

		/* Display */
		if (is_bytes_stat(name_buf) && value > 0) {
			printf("%-30s %20s (%llu)\n", name_buf,
			       format_bytes(value), (unsigned long long)value);
		} else {
			printf("%-30s %20llu\n", name_buf, (unsigned long long)value);
		}
	}

	printf("\n=== Summary ===\n");
	printf("Total entries parsed: %u\n", hdr.num_stats);
	if (anon + file + kernel > 0) {
		uint64_t total = anon + file + kernel;
		printf("Total memory: %s\n", format_bytes(total));
		printf("  - anon:   %s\n", format_bytes(anon));
		printf("  - file:   %s\n", format_bytes(file));
		printf("  - kernel: %s\n", format_bytes(kernel));
	}

	close(fd);
	return 0;
}











