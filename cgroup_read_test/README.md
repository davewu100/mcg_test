# Cgroup Read Test

这个测试套件用于测试 cgroup v2 内存统计信息的读取性能。

## 文件说明

### 脚本文件

- **setup.sh**: 主设置脚本，用于配置 CPU 性能模式和设置内存 cgroup
- **setup_mem.sh**: 创建 cgroup v2 内存层次结构，包括父级和多个叶子节点
- **mem_cgexec.sh**: 使用 cgexec 在指定的 cgroup 中启动内存分配进程
- **read.sh**: 执行读取测试，运行 readstats 程序进行性能测试

### 源代码文件

- **alloc.c**: 内存分配工具，用于在指定 cgroup 中分配和保持内存
- **readstats.c**: 读取 cgroup 统计信息的测试程序，用于性能测试

## 编译方法

### 使用 Makefile（推荐）

```bash
cd cgroup_read_test
make
```

### 手动编译

```bash
# 编译内存分配工具
gcc -o alloc alloc.c

# 编译读取统计信息工具
gcc -o readstats readstats.c
```

## 使用方法

### 1. 编译程序

```bash
cd cgroup_read_test
make
```

### 2. 设置环境

```bash
# 需要 root 权限
sudo ./setup.sh
```

这个脚本会：
- 设置 CPU 性能模式为 performance
- 创建 cgroup 内存层次结构
- 启动内存分配进程

### 3. 运行读取测试

```bash
# 运行读取测试（1000000 次迭代）
./read.sh
```

或者直接运行：

```bash
time ./readstats 1000000
```

## 依赖要求

- **cgroup-tools**: 需要安装 `cgexec` 命令
  - Debian/Ubuntu: `apt-get install cgroup-tools`
  - CentOS/RHEL: `yum install libcgroup-tools`

- **权限**: 需要 root 权限来创建和配置 cgroup

- **内核**: 需要支持 cgroup v2 的内核

## 测试说明

`readstats` 程序会：
1. 打开 `/sys/fs/cgroup/a/cgroup.stat`
2. 打开 `/sys/fs/cgroup/a/memory.stat`
3. 打开 `/sys/fs/cgroup/a/memory.numa_stat`
4. 循环读取这些文件 N 次（N 由命令行参数指定）
5. 第一次迭代会打印完整内容，后续迭代只读取不打印

## 参数说明

### setup_mem.sh 环境变量

- `N`: 叶子节点数量（默认 26）
- `LEAF_MAX`: 每个叶子的硬限制（默认 80 MiB）
- `LEAF_HIGH`: 每个叶子的软限制（默认 64 MiB）

### mem_cgexec.sh 参数

- `NUM`: 启动的进程数量（默认 26）
- `SIZE`: 每个进程分配的内存大小（默认 2M）
- `SECS`: 进程运行时间（默认 200 秒）

### readstats 参数

- `N`: 读取循环的迭代次数

## 示例

```bash
# 编译
make

# 设置（需要 root）
sudo ./setup.sh

# 测试读取性能
time ./readstats 1000000
```

## 清理

```bash
# 清理编译生成的可执行文件
make clean
```

