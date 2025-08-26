## 前置初始化脚本 (init_project.sh)

```bash
#!/bin/bash

# =============================================================================
# Design Compiler 项目初始化脚本
# =============================================================================

# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 错误处理函数
error_exit() {
    log_error "$1"
    exit 1
}

# 创建项目结构
create_project_structure() {
    local project_name="$1"
    
    if [[ -z "$project_name" ]]; then
        read -p "请输入项目名称: " project_name
    fi
    
    if [[ -d "$project_name" ]]; then
        log_warn "项目目录 '$project_name' 已存在"
        read -p "是否覆盖? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            error_exit "用户取消操作"
        fi
        rm -rf "$project_name"
    fi
    
    log_info "创建项目目录结构: $project_name"
    
    # 创建主目录
    mkdir -p "$project_name" || error_exit "无法创建项目目录"
    cd "$project_name" || error_exit "无法进入项目目录"
    
    # 创建子目录
    local dirs=("exec" "setup" "lib" "rtl_code" "work" "output" "report" "log")
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" || error_exit "无法创建目录: $dir"
        log_info "创建目录: $dir"
    done
    
    log_success "项目目录结构创建完成"
}

# 复制必要的TCL脚本模板
copy_tcl_templates() {
    log_info "创建TCL脚本模板..."
    
    
    # io.lst - IO约束文件模板
    cat > setup/io.lst << 'EOF'
# =============================================================================
# IO约束配置文件
# 格式: 端口名 驱动强度 负载电容
# 示例:
# clk 2 0.01
# data_in 2 0.005
# data_out 2 0.02
EOF

    # library.lst - 库文件配置
    cat > setup/library.lst << 'EOF'
# =============================================================================
# 库文件配置
# 格式: 库名 路径
# 示例:
# slow ../lib/slow.db
# fast ../lib/fast.db
# typical ../lib/typical.db
EOF

    # clock.lst - 时钟约束配置
    cat > setup/clock.lst << 'EOF'
# =============================================================================
# 时钟约束配置文件
# 格式: 时钟名 时钟端口 频率(MHz)
# 示例:
# clk clk 100
# clk_2x clk_2x 200
EOF

    # rst.lst - 复位约束配置
    cat > setup/rst.lst << 'EOF'
# =============================================================================
# 复位约束配置文件
# 格式: 复位信号名 复位类型(async/sync)
# 示例:
# rst_n async
# reset sync
EOF

    log_success "TCL脚本和配置文件模板创建完成"
}

# 询问用户需要从哪里拷贝文件
ask_for_file_copy() {
    log_info "请指定需要拷贝的文件路径:"
    
    # RTL代码文件
    echo
    read -p "RTL代码文件路径 (留空跳过): " rtl_path
    if [[ -n "$rtl_path" && -d "$rtl_path" ]]; then
        log_info "拷贝RTL代码文件..."
        cp -r "$rtl_path"/* rtl_code/ 2>/dev/null || log_warn "拷贝RTL文件时出现问题"
        log_success "RTL代码文件拷贝完成"
    elif [[ -n "$rtl_path" ]]; then
        log_warn "RTL路径不存在: $rtl_path"
    fi
    
    # 库文件
    echo
    read -p "库文件路径 (.db文件所在目录) (留空跳过): " lib_path
    if [[ -n "$lib_path" && -d "$lib_path" ]]; then
        log_info "拷贝库文件..."
        cp "$lib_path"/*.db lib/ 2>/dev/null || log_warn "拷贝库文件时出现问题"
        log_success "库文件拷贝完成"
    elif [[ -n "$lib_path" ]]; then
        log_warn "库文件路径不存在: $lib_path"
    fi
    
    # TCL执行脚本
    echo
    read -p "TCL执行脚本路径 (包含find_VerilogFile.tcl等) (留空跳过): " exec_path
    if [[ -n "$exec_path" && -d "$exec_path" ]]; then
        log_info "拷贝TCL执行脚本..."
        cp "$exec_path"/*.tcl exec/ 2>/dev/null || log_warn "拷贝TCL脚本时出现问题"
        log_success "TCL执行脚本拷贝完成"
    elif [[ -n "$exec_path" ]]; then
        log_warn "TCL脚本路径不存在: $exec_path"
    fi
}

# 提醒用户填写配置文件
remind_configuration() {
    echo
    log_info "=== 配置文件填写提醒 ==="
    echo
    log_warn "请务必填写以下配置文件:"
    echo "  1. setup/io.lst     - IO约束配置"
    echo "  2. setup/library.lst - 库文件配置" 
    echo "  3. setup/clock.lst   - 时钟约束配置"
    echo "  4. setup/rst.lst     - 复位约束配置"
    echo
    log_info "配置文件模板已创建，请根据项目需求进行修改"
    echo
    read -p "确认已了解配置要求? (按回车继续)"
}

# 复制主运行脚本
copy_main_script() {
    log_info "创建主运行脚本..."
    
    # 这里将之前你提供的run.sh内容嵌入
    cat > run.sh << 'EOF_RUN'
#!/bin/bash

# =============================================================================
# Design Compiler Synthesis Flow Runner Script
# =============================================================================

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
DATE=$(date "+%Y%m%d_%H%M")

# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 错误处理函数
error_exit() {
    log_error "$1"
    exit 1
}

# 检查必要的目录和文件
check_prerequisites() {
    log_info "检查先决条件..."
    
    # 检查必要的目录
    for dir in "exec" "setup"; do
        if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
            error_exit "缺少必要目录: $dir"
        fi
    done
    
    # 检查必要的TCL脚本
    local required_scripts=(
        "exec/find_VerilogFile.tcl"
        "exec/Set_Up.tcl" 
        "exec/read_design.tcl"
        "exec/set_clock.tcl"
        "exec/set_load.tcl"
        "exec/set_reset.tcl"
        "exec/compile.tcl"
        "exec/output_report.tcl"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$script" ]]; then
            error_exit "缺少必要脚本: $script"
        fi
    done
    
    # 检查配置文件
    local config_files=(
        "setup/library.lst"
        "setup/clk.lst"
        "setup/io.lst"
        "setup/rst.lst"
    )
    
    for config in "${config_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$config" ]]; then
            log_warn "配置文件不存在: $config (某些脚本可能需要此文件)"
        fi
    done
    
    log_success "先决条件检查完成"
}

# 创建输出目录
create_output_dirs() {
    log_info "创建输出目录..."
    
    local output_dirs=(
        "work"
        "output"
        "report"
        "log"
    )
    
    for dir in "${output_dirs[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
            mkdir -p "$PROJECT_ROOT/$dir" || error_exit "无法创建目录: $dir"
            log_info "创建目录: $dir"
        fi
    done
    
    log_success "输出目录创建完成"
}

# 运行TCL脚本
run_tcl_script() {
    local script_name="$1"
    local script_path="$PROJECT_ROOT/$script_name"
    local log_file="$PROJECT_ROOT/log/$(basename "$script_name" .tcl)_${DATE}.log"
    
    log_info "运行脚本: $script_name"
    
    if [[ ! -f "$script_path" ]]; then
        error_exit "脚本文件不存在: $script_path"
    fi
    
    # 运行TCL脚本并记录日志
    if tclsh "$script_path" 2>&1 | tee "$log_file"; then
        log_success "脚本执行完成: $script_name"
        return 0
    else
        log_error "脚本执行失败: $script_name"
        return 1
    fi
}

# 运行Design Compiler
run_design_compiler() {
    log_info "启动Design Compiler..."
    
    local dc_script="$PROJECT_ROOT/work/script.tcl"
    local dc_log="$PROJECT_ROOT/log/dc_shell_${DATE}.log"
    
    if [[ ! -f "$dc_script" ]]; then
        error_exit "DC脚本不存在: $dc_script"
    fi
    
    # 检查DC命令是否可用
    if ! command -v dc_shell &> /dev/null; then
        error_exit "Design Compiler (dc_shell) 未找到，请检查环境设置"
    fi
    
    cd "$PROJECT_ROOT" || error_exit "无法切换到项目目录"
    
    # 运行Design Compiler
    log_info "执行Design Compiler综合..."
    if dc_shell -t -f "$dc_script" 2>&1 | tee "$dc_log"; then
        log_success "Design Compiler执行完成"
    else
        log_error "Design Compiler执行失败，请检查日志: $dc_log"
        return 1
    fi
}

# 清理工作目录
cleanup() {
    log_info "清理临时文件..."
    
    # 删除临时文件
    find "$PROJECT_ROOT" -name "*.log.*" -type f -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name "core.*" -type f -delete 2>/dev/null || true
    
    log_success "清理完成"
}

# 显示结果摘要
show_summary() {
    log_info "=== 综合流程执行摘要 ==="
    echo
    echo "时间戳: $DATE"
    echo "项目目录: $PROJECT_ROOT"
    echo
    echo "生成的文件:"
    
    if [[ -d "$PROJECT_ROOT/output" ]]; then
        echo "  输出文件:"
        find "$PROJECT_ROOT/output" -type f -name "*${DATE}*" 2>/dev/null | sed 's/^/    /' || echo "    (无输出文件)"
    fi
    
    if [[ -d "$PROJECT_ROOT/report" ]]; then
        echo "  报告文件:"
        find "$PROJECT_ROOT/report" -type f -name "*${DATE}*" 2>/dev/null | sed 's/^/    /' || echo "    (无报告文件)"
    fi
    
    if [[ -d "$PROJECT_ROOT/log" ]]; then
        echo "  日志文件:"
        find "$PROJECT_ROOT/log" -type f -name "*${DATE}*" 2>/dev/null | sed 's/^/    /' || echo "    (无日志文件)"
    fi
    
    echo
    log_success "综合流程完成！"
}

# 帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

Design Compiler 综合流程运行脚本

选项:
  -h, --help          显示此帮助信息
  -c, --clean         清理工作目录和输出文件
  -s, --setup-only    仅运行设置阶段，不执行综合
  -d, --dc-only       仅运行Design Compiler（假设脚本已生成）
  --no-cleanup        跳过最终清理步骤

示例:
  $0                  # 运行完整流程
  $0 --clean          # 清理所有生成的文件
  $0 --setup-only     # 仅生成TCL脚本
  $0 --dc-only        # 仅运行DC综合

EOF
}

# 清理所有生成文件
clean_all() {
    log_info "清理所有生成的文件..."
    
    local dirs_to_clean=("work" "output" "report" "log" "setup/rtl_design.lst")
    
    for item in "${dirs_to_clean[@]}"; do
        if [[ -e "$PROJECT_ROOT/$item" ]]; then
            rm -rf "$PROJECT_ROOT/$item"
            log_info "删除: $item"
        fi
    done
    
    log_success "清理完成"
}

# 主函数
main() {
    local setup_only=false
    local dc_only=false
    local no_cleanup=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--clean)
                clean_all
                exit 0
                ;;
            -s|--setup-only)
                setup_only=true
                shift
                ;;
            -d|--dc-only)
                dc_only=true
                shift
                ;;
            --no-cleanup)
                no_cleanup=true
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "=== Design Compiler 综合流程开始 ==="
    log_info "时间戳: $DATE"
    
    # 检查先决条件
    check_prerequisites
    
    # 创建输出目录
    create_output_dirs
    
    if [[ "$dc_only" == true ]]; then
        # 仅运行DC
        run_design_compiler
    else
        # 运行TCL脚本生成阶段
        log_info "=== 阶段1: 脚本生成 ==="
        
        # 按照top.tcl中的顺序执行脚本
        local scripts=(
            "exec/find_VerilogFile.tcl"
            "exec/Set_Up.tcl"
            "exec/read_design.tcl" 
            "exec/set_clock.tcl"
            "exec/set_load.tcl"
            "exec/set_reset.tcl"
            "exec/compile.tcl"
            "exec/output_report.tcl"
        )
        
        for script in "${scripts[@]}"; do
            if ! run_tcl_script "$script"; then
                error_exit "脚本执行失败，流程终止"
            fi
        done
        
        log_success "=== 阶段1完成: 所有TCL脚本执行完成 ==="
        
        # 如果不是仅设置模式，继续运行DC
        if [[ "$setup_only" == false ]]; then
            log_info "=== 阶段2: Design Compiler 综合 ==="
            run_design_compiler
            log_success "=== 阶段2完成: Design Compiler 综合完成 ==="
        fi
    fi
    
    # 清理（如果需要）
    if [[ "$no_cleanup" == false ]]; then
        cleanup
    fi
    
    # 显示摘要
    show_summary
}

# 运行主函数
main "$@"
EOF_RUN

    chmod +x run.sh
    log_success "主运行脚本创建完成: run.sh"
}

# 显示完成信息
show_completion_info() {
    echo
    log_success "=== 项目初始化完成 ==="
    echo
    log_info "项目结构:"
    echo "  ├── exec/          # TCL执行脚本"
    echo "  ├── setup/         # 配置文件"
    echo "  ├── lib/           # 库文件"
    echo "  ├── rtl_code/      # RTL源代码"
    echo "  ├── work/          # 工作目录"
    echo "  ├── output/        # 输出文件"
    echo "  ├── report/        # 报告文件"
    echo "  ├── log/           # 日志文件"
    echo "  └── run.sh         # 主运行脚本"
    echo
    log_warn "下一步请务必完成以下操作:"
    echo "  1. 检查并填写 setup/ 目录下的配置文件"
    echo "  2. 确认 exec/ 目录下的TCL脚本正确"
    echo "  3. 运行 ./run.sh 开始综合流程"
    echo
}

# 主函数
main() {
    local project_name="$1"
    
    log_info "=== Design Compiler 项目初始化开始 ==="
    
    # 创建项目结构
    create_project_structure "$project_name"
    
    # 创建配置文件模板
    copy_tcl_templates
    
    # 询问文件拷贝
    ask_for_file_copy
    
    # 提醒配置
    remind_configuration
    
    # 创建主运行脚本
    copy_main_script
    
    # 显示完成信息
    show_completion_info
    
    log_success "项目初始化完成！"
}

# 运行主函数
main "$@"
```

## 使用说明

### 1. 使用方法

```bash
# 给脚本执行权限
chmod +x init_project.sh

# 运行初始化脚本
./init_project.sh [项目名称]
```

### 2. 脚本功能

1. **创建完整的项目目录结构**
2. **生成配置文件模板**：
   - `setup/filelist.tcl` - 自动查找RTL文件
   - `setup/io.lst` - IO约束配置
   - `setup/library.lst` - 库文件配置
   - `setup/clock.lst` - 时钟约束配置
   - `setup/rst.lst` - 复位约束配置

3. **询问并拷贝必要文件**：
   - RTL源代码
   - 库文件(.db)
   - TCL执行脚本

4. **自动生成主运行脚本** (`run.sh`)

### 3. 完整工作流程

```bash
# 第一步：初始化项目
./init_project.sh my_project

# 第二步：填写配置文件（根据提示）
# 编辑 setup/io.lst, setup/library.lst, setup/clock.lst, setup/rst.lst

# 第三步：运行综合流程
cd my_project
./run.sh
```

### 4. 配置文件格式说明

**io.lst**:
```
# 端口名 驱动强度 负载电容
clk 2 0.01
data_in 2 0.005
data_out 2 0.02
```

**library.lst**:
```
# 库名 路径
slow ../lib/slow.db
fast ../lib/fast.db
typical ../lib/typical.db
```

**clock.lst**:
```
# 时钟名 时钟端口 频率(MHz)
clk clk 100
clk_2x clk_2x 200
```

**rst.lst**:
```
# 复位信号名 复位类型
rst_n async
reset sync
```
