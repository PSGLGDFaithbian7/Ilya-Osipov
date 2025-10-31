### 1. 核心理念：'Plan A' 架构 (The 'Plan A' Architecture)

这个 `Makefile` 的精髓在于它定义的 "Plan A" 目录结构。这个结构的目标是实现 **验证组件的最大化复用**。

想象一下，无论你写的是一个简单的、直接激励的测试（非UVM），还是一个复杂的、基于UVM的随机化测试平台，以下两个组件几乎总是需要的：

1.  **DUT 接口 (`interface`)**：连接测试平台和设计（DUT）的桥梁。
2.  **检查器 (`checker`)**：通常包含断言（Assertions），用于实时检查DUT的行为是否符合规范。

"Plan A" 架构就是将这些**共用组件**提取出来，放在一个独立的目录里。

#### 目录结构详解

当你运行 `make setup` 后，会生成以下推荐的目录结构：

```
.
├── Makefile             # 就是这个强大的 Makefile
├── config/              # 配置文件目录
│   ├── compile_opts.f   # (可选) 额外的VCS编译选项
│   └── coverage.cfg     # (可选) 覆盖率收集的层级配置
│
├── reports/             # 存放仿真和覆盖率报告
│
├── scripts/             # 存放辅助脚本 (如 TCL)
│
├── src/                 # 存放你的RTL设计代码 (DUT, Design Under Test)
│   ├── arithmetic_unit.v
│   └── include/
│
├── testbench/           # 所有测试平台代码的根目录
│   ├── common/          # 【核心】共用组件
│   │   ├── dut_if.sv        # 例如: DUT的接口
│   │   ├── dut_checker.sv   # 例如: 断言检查器
│   │   └── include/
│   │
│   ├── non_uvm/         # 非UVM专用组件
│   │   ├── tb_top.sv      # 非UVM的顶层测试文件
│   │   ├── tb_pkg.sv      # 非UVM的包文件 (package)
│   │   └── include/
│   │
│   └── uvm/             # UVM专用组件
│       ├── uvm_tb_top.sv    # UVM的顶层测试文件
│       ├── uvm_tb_pkg.sv    # UVM测试平台的包
│       ├── agent/
│       ├── env/
│       ├── sequence_lib/
│       └── tests/
│
└── work/                # VCS的工作目录 (自动生成)
    ├── simv             # 编译后的可执行文件
    ├── sim.log          # 仿真日志
    └── project_name.fsdb # 波形文件
```

**工作原理**：
*   当你在 **非UVM模式** 下编译时 (`make non_uvm_compile`)，`Makefile` 会自动包含 `src/` + `testbench/common/` + `testbench/non_uvm/` 目录下的所有文件。
*   当你在 **UVM模式** 下编译时 (`make uvm_compile`)，`Makefile` 会自动包含 `src/` + `testbench/common/` + `testbench/uvm/` 目录下的所有文件。

这样，`dut_if.sv` 和 `dut_checker.sv` 就不需要在 `non_uvm` 和 `uvm` 目录中各写一份，实现了完美的复用。

---

### 2. 如何使用 (How to Use)

#### 步骤 1: 初始化项目 (Project Setup)

如果你是从零开始一个新项目，第一步是创建目录结构。

```bash
# 自动创建 'Plan A' 架构的所有目录和模板配置文件
make setup
```
这个命令会创建 `src/`, `testbench/common/`, `testbench/non_uvm/`, `testbench/uvm/` 等目录，以及 `config/` 目录下的模板文件。

#### 步骤 2: 添加你的文件 (Add Your Files)

将你的设计和验证文件放入对应的目录：
*   **RTL设计文件** (如 `adder.v`, `control.v`) -> `src/`
*   **共用的 interface 和 checker** -> `testbench/common/`
*   **非UVM的 testbench** (如 `tb_top.sv`) -> `testbench/non_uvm/`
*   **UVM的 testbench** (如 `agent`, `env`, `test` 等) -> `testbench/uvm/`

#### 步骤 3: 运行检查 (Run Checks)

在编译之前，运行检查命令，确保 `Makefile` 能正确找到所有文件。

```bash
# 检查工具、目录结构和文件
make check

# 查看 Makefile 发现了哪些文件（强烈推荐）
make list_files
```
`list_files` 会分类列出所有它找到的源文件、公共文件、UVM文件等，便于你确认文件是否放置正确。

#### 步驟 4: 编译和仿真 (Compile and Simulate)

这是最常用的部分。`Makefile` 通过变量来控制编译和仿真的行为。

**A. 运行非UVM仿真**

```bash
# 编译非UVM testbench (会自动找到 tb_top)
make non_uvm_compile

# 运行仿真 (默认运行1000个case，可通过 NUM_CASES 修改)
make non_uvm_sim NUM_CASES=50
```
或者直接一步到位：
```bash
make non_uvm_sim
```

**B. 运行UVM仿真**

UVM模式通过设置 `UVM_ENABLE=1` 来激活。

```bash
# 编译 UVM testbench (需要 UVM_ENABLE=1)
# TOP_MODULE 通常是 uvm_tb_top
make compile UVM_ENABLE=1 TOP_MODULE=uvm_tb_top

# 运行一个指定的 UVM test (TESTCASE)
# SEED 可以指定随机种子
make sim UVM_ENABLE=1 TOP_MODULE=uvm_tb_top TESTCASE=basic_test SEED=123
```
为了简化，`Makefile` 提供了更方便的快捷方式：
```bash
# 编译 UVM testbench
make uvm_compile

# 运行 UVM test
make uvm_sim TESTCASE=random_test

# 运行 UVM 回归测试 (会自动运行 basic_test, random_test, constraint_test)
make uvm_regress
```

**C. 运行带覆盖率的仿真**

通过设置 `COV_ENABLE=1` 来开启覆盖率收集。

```bash
# 运行带覆盖率的UVM仿真
make uvm_sim TESTCASE=some_test COV_ENABLE=1

# 生成覆盖率报告
make cov_report

# 打开覆盖率图形界面
make cov_gui
```

**D. 生成波形并查看**

```bash
# 运行仿真并dump波形 (FSDB格式)
make sim_waves UVM_ENABLE=1 TESTCASE=my_test

# 自动打开 Verdi 查看最新的波形文件
make wave
```

#### 步骤 5: 调试 (Debug)

```bash
# 启动 Verdi 进入调试模式 (需要先编译)
make debug UVM_ENABLE=1
```

#### 步骤 6: 清理 (Clean Up)

```bash
# 清理工作目录 (保留 reports)
make clean

# 深度清理，删除 work 和 reports 目录
make clean_all
```

---

### 3. 主要功能和命令解析 (Key Features and Command Breakdown)

`Makefile` 提供了非常丰富的命令，可以通过 `make help` 查看。这里列出一些最重要的：

| 命令 | 功能描述 |
| :--- | :--- |
| `make setup` | **初始化项目**，创建 "Plan A" 目录结构和配置文件模板。 |
| `make check` | **飞行前检查**，确认工具、目录和文件都已就绪。 |
| `make list_files` | **列出所有被发现的文件**，按类别（src, common, uvm）显示，非常适合调试。 |
| | |
| `make compile` | **编译**。根据 `UVM_ENABLE` 决定编译UVM还是非UVM。 |
| `make sim` | **仿真**。根据 `UVM_ENABLE` 和 `TESTCASE` 运行测试。 |
| `make non_uvm_sim` | **运行非UVM仿真**的快捷方式。 |
| `make uvm_sim` | **运行UVM仿真**的快捷方式。 |
| `make uvm_regress` | **UVM回归测试**，自动运行多个预设的测试用例。 |
| | |
| `make sim_waves` | 运行仿真并**生成波形文件**（FSDB）。 |
| `make wave` | **自动打开Verdi查看最新波形**，无需手动指定文件名。 |
| `make debug` | **启动Verdi进行交互式调试**。 |
| | |
| `make cov_sim` | 运行带**覆盖率收集**的仿真 (`COV_ENABLE=1`)。 |
| `make cov_report` | **生成覆盖率报告**。 |
| `make cov_gui` | **打开Verdi覆盖率分析**界面。 |
| | |
| `make clean` / `clean_all` | **清理工作区**。 |
| `make help` | **显示帮助信息**，列出所有可用命令和变量。 |

#### 可配置变量 (Configurable Variables)

你可以在 `make` 命令后面添加这些变量来控制流程：

| 变量 | 默认值 | 描述 |
| :--- | :--- | :--- |
| `PROJECT_NAME` | `arithmetic_unit` | 项目名称，用于波形和日志文件命名。 |
| `TOP_MODULE` | `tb_top` | 仿真的顶层模块。UVM模式下通常是 `uvm_tb_top`。 |
| `TESTCASE` | `basic_test` | UVM模式下要运行的测试用例名称 (`+UVM_TESTNAME`)。 |
| `UVM_ENABLE` | `(unset)` | **设为 `1` 以启用UVM模式**。这是模式切换的关键。 |
| `COV_ENABLE` | `(unset)` | **设为 `1` 以启用覆盖率收集**。 |
| `SEED` | `(timestamp)` | 随机种子。 |
| `PLUSARGS` | `(empty)` | 传递给仿真的额外 `+plusargs` 参数。 |

### 总结


