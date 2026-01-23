/* Realistic cgroup stats reader for performance comparison
 * Simulates real-world usage patterns: periodic reads over a time period
 * without actual delays between reads for fast performance comparison.
 *
 * Usage:
 *   readstats_realistic <duration_seconds> <reads_per_second>
 *
 * Example: readstats_realistic 10 1
 *   - Simulates 10 seconds of monitoring with 1 read per second (10 reads total)
 *   - But executes all reads consecutively for fast performance testing
 */
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>

static void read_stats(int f_memst, int f_memnuma, int read_num) {
    char buf[8192];
    ssize_t n;
    volatile int dummy = 0;  // 防止编译器优化

    // Read memory.stat
    lseek(f_memst, 0, SEEK_SET);
    n = read(f_memst, buf, sizeof(buf)-1);
    if (n > 0) {
        buf[n] = '\0';
        // 模拟一些处理工作 - 解析数值
        for (int i = 0; i < n && i < 100; i++) {
            if (buf[i] >= '0' && buf[i] <= '9') {
                dummy += buf[i] - '0';
            }
        }
    }

    // Read memory.numa_stat
    lseek(f_memnuma, 0, SEEK_SET);
    n = read(f_memnuma, buf, sizeof(buf)-1);
    if (n > 0) {
        buf[n] = '\0';
        // 模拟一些处理工作 - 解析数值
        for (int i = 0; i < n && i < 100; i++) {
            if (buf[i] >= '0' && buf[i] <= '9') {
                dummy += buf[i] - '0';
            }
        }
    }

    // 防止dummy被优化掉
    if (dummy < 0) printf("Dummy: %d\n", dummy);
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("USAGE: %s <duration_seconds> <reads_per_second>\n", argv[0]);
        printf("Example: %s 10 1  # Simulate 10 seconds with 1 read/second (10 total reads)\n", argv[0]);
        return 1;
    }

    int duration_seconds = atoi(argv[1]);
    int reads_per_second = atoi(argv[2]);

    if (duration_seconds <= 0 || reads_per_second <= 0) {
        printf("Error: duration and reads_per_second must be positive\n");
        return 1;
    }

    int total_reads = duration_seconds * reads_per_second;
    printf("Simulating %d seconds with %d reads/second = %d total reads\n",
           duration_seconds, reads_per_second, total_reads);

    // Open files once
    int f_memst = open("/sys/fs/cgroup/a/memory.stat", O_RDONLY);
    int f_memnuma = open("/sys/fs/cgroup/a/memory.numa_stat", O_RDONLY);
    if (f_memst < 0 || f_memnuma < 0) {
        perror("open");
        return 1;
    }

    // Record start time
    struct timeval start_time, end_time;
    gettimeofday(&start_time, NULL);

    // Perform all reads consecutively (no delays for performance testing)
    for (int i = 0; i < total_reads; i++) {
        read_stats(f_memst, f_memnuma, i + 1);
    }

    // Record end time
    gettimeofday(&end_time, NULL);

    // Calculate elapsed time
    double elapsed_seconds = (end_time.tv_sec - start_time.tv_sec) +
                            (end_time.tv_usec - start_time.tv_usec) / 1000000.0;

    printf("Completed %d reads in %.6f seconds\n", total_reads, elapsed_seconds);
    printf("Average time per read: %.6f microseconds\n",
           (elapsed_seconds * 1000000.0) / total_reads);
    printf("Effective rate: %.2f reads/second\n", total_reads / elapsed_seconds);

    close(f_memst);
    close(f_memnuma);
    return 0;
}
