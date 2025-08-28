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
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" # 确保警告为黄色
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" # 确保错误为红色
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

    [[ ! -f "$dc_script" ]] && error_exit "DC脚本不存在: $dc_script"

    # 自动探测 dc 可执行文件（优先 Tcl 版）
    local dc_bin=""
    for cand in dc_shell-t dc_shell-xg-t dc_shell; do
        if command -v "$cand" >/dev/null 2>&1; then
            dc_bin="$cand"
            break
        fi
    done
    [[ -z "$dc_bin" ]] && error_exit "Design Compiler 未找到，请检查环境设置（PATH/许可等）"

    # 切换到work目录
    cd "$PROJECT_ROOT/work" || error_exit "无法切换到work目录"

    log_info "在work目录执行Design Compiler综合（${dc_bin} -f $(basename "$dc_script")）..."
    if "$dc_bin" -f "$dc_script" 2>&1 | tee "$dc_log"; then
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