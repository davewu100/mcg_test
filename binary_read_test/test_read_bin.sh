#!/bin/bash
# 手工测试读取 binary 文件

CGROUP_PATH="${1:-/sys/fs/cgroup/a}"
STAT_BIN="$CGROUP_PATH/memory.stat_bin"

echo "=== 测试文件权限 ==="
ls -lh "$STAT_BIN"

echo ""
echo "=== 尝试使用 cat 读取 ==="
if cat "$STAT_BIN" 2>&1; then
    echo "cat 成功"
else
    echo "cat 失败: $?"
fi

echo ""
echo "=== 尝试使用 dd 读取 ==="
if dd if="$STAT_BIN" bs=1024 count=1 2>/dev/null | hexdump -C | head -20; then
    echo "dd 成功"
else
    echo "dd 失败"
fi

echo ""
echo "=== 尝试使用 Python 读取 ==="
python3 << EOF
import os
try:
    fd = os.open("$STAT_BIN", os.O_RDONLY)
    print(f"文件描述符: {fd}")
    data = os.read(fd, 1024)
    print(f"读取到 {len(data)} 字节")
    if len(data) > 0:
        print("前32字节 (hex):", data[:32].hex())
        print("前32字节 (repr):", repr(data[:32]))
    os.close(fd)
except Exception as e:
    print(f"错误: {e}")
EOF

echo ""
echo "=== 尝试使用 C 程序读取 ==="
cat > /tmp/test_read_bin.c << 'CCODE'
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

int main(int argc, char *argv[]) {
    const char *path = argc > 1 ? argv[1] : "/sys/fs/cgroup/a/memory.stat_bin";
    int fd;
    char buf[1024];
    ssize_t n;
    
    printf("尝试打开: %s\n", path);
    fd = open(path, O_RDONLY);
    if (fd < 0) {
        printf("open 失败: %s (errno=%d)\n", strerror(errno), errno);
        return 1;
    }
    
    printf("文件描述符: %d\n", fd);
    n = read(fd, buf, sizeof(buf));
    if (n < 0) {
        printf("read 失败: %s (errno=%d)\n", strerror(errno), errno);
        close(fd);
        return 1;
    }
    
    printf("成功读取 %zd 字节\n", n);
    if (n > 0) {
        printf("前32字节 (hex): ");
        for (int i = 0; i < n && i < 32; i++) {
            printf("%02x ", (unsigned char)buf[i]);
        }
        printf("\n");
    }
    
    close(fd);
    return 0;
}
CCODE

gcc -o /tmp/test_read_bin /tmp/test_read_bin.c 2>&1
if [ $? -eq 0 ]; then
    /tmp/test_read_bin "$STAT_BIN"
else
    echo "编译失败"
fi











