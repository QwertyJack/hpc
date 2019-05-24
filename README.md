# singularity-hello-world
Singularity 测试

本示例将

- 安装 Singularity 最新版
- 构建一个测试应用
- 测试性能

## 安装

目前较新版只能编译安装

- 安装 golang，最低 1.11
- 下载源码
- 编译/安装

详见[文档](https://www.sylabs.io/guides/3.2/user-guide/installation.html)

## 构建

下文以 [OpenFOAM](https://www.openfoam.com/download/install-binary-linux.php) 为例

### 构建 SIF

拉取 Singularity 镜像文件(SIF) 的语法为：

```
singularity pull [sif-file] <bootstrap>://<path>[:tag]
```

Singularity 对 Docker 支持较好，可以直接从 docker 镜像构建 Singularity 镜像文件(SIF)：

```bash
singularity pull openfoam6.sif docker://openfoam/openfoam6-paraview54
```

当前目录会生成一个名为 `openfoam6.sif` 的可执行文件

为了使 sif 更加友好，这里使用["定义文件"构建 SIF](https://www.sylabs.io/guides/3.2/user-guide/definition_files.html)

```bash
$ cd openfoam
$ cat openfoam6.def
BootStrap: docker
From: openfoam/openfoam6-paraview54

%post
    ln -sf /bin/bash /bin/sh
    echo '. /opt/openfoam6/etc/bashrc' >> $SINGULARITY_ENVIRONMENT$ cat openfoam6.def

%label
    Author Jack

# build 需要 root 权限
$ sudo singularity build openfoam6.sif openfoam6.def
```

### 构建支持 OFED 的 SIF

[使用交互环境](https://www.sylabs.io/guides/3.2/user-guide/build_a_container.html#creating-writable-sandbox-directories)构建，
步骤如下：

- 从 Ubuntu docker 镜像创建沙箱环境: `sudo singularity build --sandbox of6_ib/ docker://ubuntu:xenial`
- 从沙箱环境进入交互环境: `sudo singularity shell -w of6_ib/`
- [安装 OFED 驱动](https://community.mellanox.com/s/article/how-to-create-a-docker-container-with-rdma-accelerated-applications-over-100gb-infiniband-network#jive_content_id_Installation_Mellanox_OFED_for_Ubuntu_on_a_Host)
- [安装 OpenFOAM 6](https://openfoam.org/download/6-ubuntu/)
- 从沙箱环境构建 SIF: `sudo singularity build of6_ib.sif of6_ib/`

如果运行环境没有 Infiniband 则运行时会报错:

```
[[60454,1],0]: A high-performance Open MPI point-to-point messaging module
was unable to find any relevant network interfaces:

Module: OpenFabrics (openib)
  Host: singularity-builder

Another transport will be used instead, although this may result in
  lower performance.
```

几个有用的 docker 镜像：

- [ubuntu:xenial](https://hub.docker.com/_/ubuntu/scans/library/ubuntu/xenial)
- [openfoam/openfoam6-paraview54](https://hub.docker.com/r/openfoam/openfoam6-paraview54)
- [mellanox/ubuntu_mofed](https://hub.docker.com/r/mellanox/ubuntu_mofed)

### 运行

```bash
# shell 方式运行
#   - 当前目录会以 overlay 方式挂在到容器中, 用 --pwd 指定当前目录
singularity shell openfoam6.sif

# run 方式运行
#   - 如果定义了 %runscript 则执行这部分代码片段
#   - 如果从 docker 导入则执行 ENTRYPOINT
#   - 否则执行默认 shell
singularity run openfoam6.sif

# exec 方式运行
singularity exec openfoam6.sif simpleFoam -help
```

## 测试

### 环境

- Singularity: 3.2.0
- CPU: Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz (14c x2)
- RAM: 256GB
- OS: CentOS Linux release 7.3.1611 (Core)
- 任务队列: slurm 17.11.13-2
- OpenFOAM: v1812(native) / 6-d3fd147e6c65(singularity)
- Open MPI: 1.10.4(环境 + docker 内建)

### 测试用例

参考 [benchmarks/motorbike](https://github.com/OpenFOAM/OpenFOAM-Intel/tree/master/benchmarks/motorbike)

```
cd motorbike

# init mesh
./Mesh 100 40 40

# set task
./Setup 28

# run
# ./Solve
# 报错 `not enough slots available in the system', 添加 -oversubscribe 参数
mpirun -np 28 -oversubscribe simpleFoam -parallel
```

使用 `time $@` 方式计时，测试 3 次

### 单节点测试结果

- Native 方式运行: `time mpirun -np 28 -oversubscribe simpleFoam -parallel`

| 编号 | 计时 |
| -- | -- |
| 1  | 1131.81s user 85.91s system 2784% cpu 43.736 total |
| 2  | 1139.51s user 97.97s system 2764% cpu 44.769 total |
| 3  | 1155.45s user 97.17s system 2768% cpu 45.253 total |

- Singularity + 内建 mpi: `time singularity exec ~/bin/openfoam6.sif bash -c 'mpirun -np 28 -oversubscribe simpleFoam -parallel'`

| 编号 | 计时 |
| -- | -- |
| 1  | 1101.80s user 115.76s system 2680% cpu 45.427 total |
| 2  | 1109.00s user 113.99s system 2659% cpu 45.986 total |
| 3  | 1105.76s user 119.69s system 2679% cpu 45.738 total |

- Singularity + 环境 mpi: `time mpirun -np 28 -oversubscribe singularity exec ~/bin/openfoam6.sif bash -c 'simpleFoam -parallel'`

| 编号 | 计时 |
| -- | -- |
| 1  | 1114.46s user 138.48s system 2758% cpu 45.426 total |
| 2  | 1109.87s user 130.72s system 2756% cpu 45.001 total |
| 3  | 1116.73s user 142.25s system 2771% cpu 45.423 total |

### 双节点测试结果

测试用例中分成 40 个 task，均分给两个节点；迭代次数从默认 250 改为 50.

由于 Singularity + 内建 mpi 在启动时并不会跨节点启动 Singularity，进而不会用到第二个节点，
所以只有 Singularity + 环境 mpi 才可以启动多个节点。

OpenFOAM 6 自带 mpi 具有 Infiniband 支持 (`ompi_info | grep openib`),
即默认情况下使用 Infiniband 网络。
如果 sif 容器中没有 ofed 驱动，mpi 启动时会有错误提示:
```
...
libibverbs: Warning: couldn't load driver 'mlx5': libmlx5-rdmav2.so: cannot open shared object file: No such file or directory
libibverbs: Warning: couldn't load driver 'mlx4': libmlx4-rdmav2.so: cannot open shared object file: No such file or directory
libibverbs: Warning: no userspace device-specific driver found for /sys/class/infiniband_verbs/uverbs0
...
```
进而 mpi 使用 Ethernet 运行任务。
使用参数 `--mca pml ob1 --mca btl ^openib` 禁用 Infiniband 强制 mpi 使用 Ethernet.
显式使用 Infiniband 可以使用参数 `--mca btl openib,self,vader`.
参考[这里](https://users.open-mpi.narkive.com/eEsg7bo8/ompi-users-forcing-openmpi-to-use-ethernet-interconnect-instead-of-infiniband)和[这里](https://www.open-mpi.org/faq/?category=openfabrics#ib-btl)。

使用 Ethernet 时观察到流量情况如下:

```
MB/s            en          ib
                in  out     in  out
mic01(master)   600 30      30  600
mic02(slave)    30  600     600 30
```

- Native + Ethernet: `time mpirun -np 40 --mca pml ob1 --mca btl ^openib -oversubscribe simpleFoam -parallel`

| 编号 | 计时 |
| -- | -- |
| 1  | 234.29s user 248.92s system 1953% cpu 24.735 total |
| 2  | 231.29s user 237.88s system 1947% cpu 24.091 total |
| 3  | 241.41s user 252.77s system 1806% cpu 27.356 total |

- Singularity + Ethernet: `time mpirun -np 40 --mca pml ob1 --mca btl ^openib -oversubscribe singularity exec ~/bin/openfoam6.sif bash -c 'simpleFoam -parallel'`

| 编号 | 计时 |
| -- | -- |
| 1  | 204.17s user 281.96s system 1941% cpu 25.034 total |
| 2  | 205.12s user 283.39s system 1683% cpu 29.022 total |
| 3  | 213.04s user 305.39s system 1962% cpu 26.421 total |

- Native + Infiniband: `time mpirun -np 40 -oversubscribe simpleFoam -parallel`

| 编号 | 计时 |
| -- | -- |
| 1  | 137.07s user 21.95s system 1465% cpu 10.853 total |
| 2  | 136.14s user 15.89s system 1855% cpu 8.192 total  |
| 3  | 135.97s user 16.32s system 1848% cpu 8.237 total  |

- Singularity + Infiniband: `time mpirun -np 40 -oversubscribe singularity exec ~/bin/of6_ib.sif bash -c 'simpleFoam -parallel'`

| 编号 | 计时 |
| -- | -- |
| 1  | 132.97s user 41.32s system 1659% cpu 10.504 total |
| 2  | 130.86s user 35.42s system 1836% cpu 9.056 total  |
| 3  | 131.40s user 34.84s system 1849% cpu 8.990 total  |

### 四节点测试结果

同双节点

```
# Native 迭代 50 次
69.03s user 8.46s system 930% cpu 8.328 total
68.75s user 8.07s system 941% cpu 8.159 total
69.11s user 7.81s system 940% cpu 8.179 total

# Singularity 迭代 50 次
67.23s user 18.19s system 937% cpu 9.113 total
66.21s user 18.21s system 937% cpu 9.008 total
66.54s user 17.86s system 939% cpu 8.983 total

# Native 迭代 250 次
326.45s user 29.08s system 985% cpu 36.059 total
322.46s user 27.66s system 985% cpu 35.542 total
324.59s user 28.46s system 981% cpu 35.982 total

# Singularity 迭代 250 次
311.39s user 42.93s system 985% cpu 35.961 total
311.83s user 42.69s system 982% cpu 36.100 total
311.03s user 42.92s system 982% cpu 36.037 total
```

由于 Native 和 Singularity 中 OpenFOAM 的版本不一致，所以二者效率略有不同。
