/* 简单的二进制文件读取测试程序 */
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdint.h>

int main(int argc, char *argv[]) {
    const char *path = argc > 1 ? argv[1] : "/sys/fs/cgroup/a/memory.stat_bin";
    int fd;
    uint8_t buf[4096];
    ssize_t n;
    
    printf("=== 测试读取二进制文件 ===\n");
    printf("文件路径: %s\n", path);
    
    /* 尝试打开文件 */
    fd = open(path, O_RDONLY);
    if (fd < 0) {
        printf("❌ open() 失败: %s (errno=%d)\n", strerror(errno), errno);
        printf("\n可能的原因:\n");
        printf("1. 文件不存在\n");
        printf("2. 权限不足 (文件权限是 ----------)\n");
        printf("3. 内核未重新编译，修复未生效\n");
        printf("4. cgroup 在内核更新前创建，需要重新创建\n");
        return 1;
    }
    
    printf("✅ 文件打开成功，文件描述符: %d\n", fd);
    
    /* 尝试读取文件 */
    n = read(fd, buf, sizeof(buf));
    if (n < 0) {
        printf("❌ read() 失败: %s (errno=%d)\n", strerror(errno), errno);
        close(fd);
        return 1;
    }
    
    if (n == 0) {
        printf("⚠️  读取到 0 字节 (文件可能为空或未实现)\n");
    } else {
        printf("✅ 成功读取 %zd 字节\n", n);
        
        /* 显示前32字节的十六进制 */
        printf("\n前32字节 (hex):\n");
        for (ssize_t i = 0; i < n && i < 32; i++) {
            printf("%02x ", buf[i]);
            if ((i + 1) % 16 == 0)
                printf("\n");
        }
        if (n < 32)
            printf("\n");
        
        /* 检查 magic number */
        if (n >= 4) {
            uint32_t magic = (uint32_t)buf[0] | 
                             ((uint32_t)buf[1] << 8) |
                             ((uint32_t)buf[2] << 16) |
                             ((uint32_t)buf[3] << 24);
            printf("\nMagic number: 0x%08x (应该是 0x4D454D43 'MEMC')\n", magic);
            if (magic == 0x4D454D43) {
                printf("✅ Magic number 正确！\n");
            } else {
                printf("⚠️  Magic number 不匹配\n");
            }
        }
    }
    
    close(fd);
    return 0;
}











