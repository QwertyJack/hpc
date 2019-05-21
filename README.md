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

### 测试结果

使用 `time $@` 方式计时，测试 3 次

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
