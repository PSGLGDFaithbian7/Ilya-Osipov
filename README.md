# Spyglass Makefile - 目录架构与使用方法

## 目录结构

```
项目根目录/
├── Makefile                    # 这个文件
├── rtl/                        # RTL设计文件
│   ├── *.sv
│   └── *.v
├── include/                    # 头文件
│   └── *.vh
├── config/                     # 配置文件（自动生成）
│   ├── rtl_files.f            # RTL文件列表
│   ├── include_files.f        # include路径
│   └── waivers.awl            # waiver文件（手动创建）
├── scripts/                    # TCL脚本
│   └── run_spyglass.tcl       # 核心脚本（需手动创建）
├── results/                    # 分析结果
│   ├── lint/
│   ├── cdc/
│   └── rdc/
└── logs/                       # 运行日志
```

## 基本使用流程

### 1. 首次使用
```bash
# 创建目录结构和文件列表
make setup

# 将RTL文件放入 rtl/ 目录
# 创建 scripts/run_spyglass.tcl（见下方模板）
```

### 2. 运行分析
```bash
# Lint检查
make run_lint

# CDC检查
make run_cdc

# RDC检查
make run_rdc
```

### 3. 查看结果
```bash
# 自动打开HTML报告
make view_lint
make view_cdc
make view_rdc

# 查看项目状态
make status
``
```

## 常用命令

```bash
# 指定顶层模块
make run_lint TOP_MODULES="cpu mmu"

# 指定RTL路径
make run_lint RTL_ROOT=./design/rtl

# 查看帮助
make help

# 清理结果
make clean              # 清理结果和日志
make distclean          # 深度清理
make clean_old_runs     # 只保留最近5次运行
```

## 关键变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PROJECT_NAME` | rtl_project | 项目名 |
| `TOP_MODULES` | top_module | 顶层模块 |
| `RTL_ROOT` | ./rtl | RTL文件目录 |
| `INCLUDE_DIRS` | ./include ./rtl/include | include路径 |
