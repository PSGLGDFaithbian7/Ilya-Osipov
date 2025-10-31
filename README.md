## 系统架构与文件组织

### 1. 完整目录结构

```
dc_synthesis_system/
│
├── Makefile                    # 主控制文件
│
├── config/                     # 配置目录
│   └── project_config.yaml    # 项目配置文件
│
├── rtl/                        # RTL源文件目录
│   ├── src/                   # 主要RTL源文件
│   │   ├── top.v              # 顶层模块
│   │   ├── module1.v          # 子模块
│   │   └── module2.sv         # SystemVerilog文件
│   │
│   ├── include/               # ← 头文件放这里！
│   │   ├── defines.vh         # 全局宏定义
│   │   ├── parameters.vh      # 参数定义
│   │   ├── typedef.svh        # SystemVerilog类型定义
│   │   └── config.vh          # 配置相关宏
│   │
│   ├── ip/                    # IP核文件
│   │   └── memory/            # 存储器IP
│   │
│   └── tb/                    # 测试平台（综合时会被忽略）
│
├── lib/                        # 工艺库文件目录
│   ├── tcbn65lpwc_ccs.db     # 最差条件库
│   ├── tcbn65lptc_ccs.db     # 典型条件库
│   ├── tpan65lpnv2od3wc.db   # IO库
│   └── dw_foundation.sldb     # DesignWare库
│
├── scripts/                    # 脚本目录
│   ├── synthesis_main.tcl     # 主综合脚本
│   ├── lib/                   # TCL库文件
│   │   ├── config_parser.tcl  # 配置解析
│   │   ├── rtl_finder.tcl     # RTL查找
│   │   ├── constraint_gen.tcl # 约束生成
│   │   ├── power_analysis.tcl # 功耗分析
│   │   ├── report_gen.tcl     # 报告生成
│   │   └── utils.tcl          # 工具函数
│   └── tools/                 # 工具脚本
│       ├── qor_analyzer.tcl   # QoR分析
│       └── config_validator.tcl # 配置验证
│
├── work/                       # 工作目录（自动生成）
│
├── output/                     # 输出目录（按时间戳组织）
│   └── 20241209_143022/       # 时间戳目录
│       ├── netlist/           # 网表输出
│       ├── constraints/       # 约束文件
│       └── parasitics/        # 寄生参数
│
├── report/                     # 报告目录（按时间戳组织）
│   └── 20241209_143022/       # 时间戳目录
│       ├── timing/            # 时序报告
│       ├── area/              # 面积报告
│       ├── power/             # 功耗报告
│       ├── clock/             # 时钟报告
│       ├── qor/               # QoR报告
│       └── analysis/          # 分析报告
│
└── log/                        # 日志目录
    └── synthesis_*.log         # 综合日志
```

### 2. 头文件使用方法

#### 2.1 头文件位置
头文件应放在 `rtl/include/` 目录下，支持的扩展名：
- `.vh` - Verilog头文件
- `.svh` - SystemVerilog头文件
- `.h` - 通用头文件

#### 2.2 头文件示例

**rtl/include/defines.vh:**
```verilog
// Global defines
`ifndef DEFINES_VH
`define DEFINES_VH

`define DATA_WIDTH 32
`define ADDR_WIDTH 16
`define FIFO_DEPTH 64

// Feature enables
`define USE_CLOCK_GATING
`define ENABLE_DEBUG

// Timing parameters
`define SETUP_TIME 0.1
`define HOLD_TIME 0.05

`endif
```

**rtl/include/parameters.vh:**
```verilog
// Global parameters
`ifndef PARAMETERS_VH
`define PARAMETERS_VH

parameter IDLE = 3'b000;
parameter INIT = 3'b001;
parameter RUN  = 3'b010;
parameter DONE = 3'b100;

parameter CLK_FREQ = 250_000_000;  // 250MHz

`endif
```

#### 2.3 在RTL中使用头文件

**rtl/src/top.v:**
```verilog
`include "defines.vh"
`include "parameters.vh"

module top (
    input  wire clk,
    input  wire rst_n,
    input  wire [`DATA_WIDTH-1:0] data_in,
    output reg  [`DATA_WIDTH-1:0] data_out
);
    
    reg [2:0] state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            // State machine using parameters from header
            case (state)
                IDLE: state <= INIT;
                INIT: state <= RUN;
                RUN:  state <= DONE;
                DONE: state <= IDLE;
            endcase
    end
    
`ifdef USE_CLOCK_GATING
    // Clock gating logic
`endif

endmodule
```

### 3. 配置文件设置

在 `config/project_config.yaml` 中配置头文件路径和宏定义：

```yaml
rtl:
  # RTL源文件搜索目录
  search_dirs:
    - "./rtl/src"
    - "./rtl/ip"
    
  # 头文件搜索目录
  include_dirs:
    - "./rtl/include"          # 主要头文件目录
    - "./rtl/src/common"        # 可以有多个
    - "./rtl/ip/includes"       # IP的头文件
    
  # 综合时定义的宏
  defines:
    - "SYNTHESIS=1"             # 综合标志
    - "TSMC65=1"               # 工艺标志
    - "USE_CLOCK_GATING=1"     # 功能开关
    - "DATA_WIDTH=32"          # 带值的宏定义
    - "DEBUG_LEVEL=2"          # 调试级别
    
  # 文件扩展名
  file_extensions:
    - "*.v"
    - "*.sv"
    - "*.vhd"
    # 注意：.vh 和 .svh 头文件会被自动识别但不会被analyze
```

### 4. 系统工作流程

```
1. 初始化阶段
   ├── 读取 config/project_config.yaml
   ├── 验证配置合法性
   └── 创建工作目录结构

2. RTL准备阶段
   ├── 递归搜索 rtl/src 和 rtl/ip 目录
   ├── 找到所有 .v .sv .vhd 文件
   ├── 设置 include 路径（rtl/include）
   └── 应用宏定义（SYNTHESIS=1 等）

3. 综合阶段
   ├── analyze 时加入 +incdir+./rtl/include
   ├── 应用 -define 选项
   ├── elaborate 顶层模块
   └── 执行 compile_ultra

4. 约束应用
   ├── 读取多时钟配置并创建时钟
   ├── 自动生成时钟间 false path
   ├── 应用多复位约束
   └── 应用多组IO约束

5. 输出生成
   ├── 生成网表到 output/时间戳/netlist/
   ├── 生成报告到 report/时间戳/各类别/
   └── 生成QoR分析到 report/时间戳/analysis/
```

### 5. 重要文件说明

| 文件类型 | 位置 | 说明 |
|---------|------|------|
| RTL源文件 | `rtl/src/` | 主要设计文件 |
| 头文件 | `rtl/include/` | 宏定义、参数、类型定义 |
| IP文件 | `rtl/ip/` | 第三方IP或生成的IP |
| 工艺库 | `lib/` | .db文件、.lib文件 |
| 配置文件 | `config/project_config.yaml` | 所有配置集中在此 |
| 网表输出 | `output/时间戳/netlist/` | 综合后的Verilog网表 |
| 时序报告 | `report/时间戳/timing/` | setup/hold时序分析 |
| QoR报告 | `report/时间戳/analysis/` | HTML格式的综合质量报告 |

### 6. 使用示例

```bash
# 1. 创建头文件
mkdir -p rtl/include
echo '`define DATA_WIDTH 32' > rtl/include/defines.vh

# 2. 配置include路径（已在yaml中配置）

# 3. 运行综合（会自动包含头文件路径）
make synthesize

# 4. 查看日志确认include路径
grep "incdir" log/synthesis_*.log
# 输出类似: analyze -format sverilog -vcs "+incdir+./rtl/include" -define SYNTHESIS=1 ...
```

这个系统完全支持Verilog/SystemVerilog的头文件机制，通过配置文件灵活管理include路径和宏定义。