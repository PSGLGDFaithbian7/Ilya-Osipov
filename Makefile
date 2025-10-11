# =============================================================================
# Design Compiler Synthesis Flow Makefile
# =============================================================================

# 配置变量
SHELL := /bin/bash
PROJECT_ROOT := $(shell pwd)
DATE := $(shell date "+%Y%m%d_%H%M")

# 颜色输出定义
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# 日志宏定义
define log_info
	@echo -e "$(BLUE)[INFO]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - $(1)"
endef

define log_warn
	@echo -e "$(YELLOW)[WARN]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - $(1)"
endef

define log_error
	@echo -e "$(RED)[ERROR]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - $(1)" >&2
endef

define log_success
	@echo -e "$(GREEN)[SUCCESS]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - $(1)"
endef

# 必要的TCL脚本列表
TCL_SCRIPTS := exec/find_VerilogFile.tcl \
               exec/Set_Up.tcl \
               exec/read_design.tcl \
               exec/set_clock.tcl \
               exec/set_load.tcl \
               exec/set_reset.tcl \
               exec/compile.tcl \
               exec/output_report.tcl

# 配置文件列表
CONFIG_FILES := setup/library.lst \
                setup/clk.lst \
                setup/io.lst \
                setup/rst.lst

# 输出目录
OUTPUT_DIRS := work output report log

# DC可执行文件探测
DC_BIN := $(shell for cmd in dc_shell-t dc_shell-xg-t dc_shell; do \
             command -v $$cmd >/dev/null 2>&1 && echo $$cmd && break; \
          done)

# 默认目标
.PHONY: all
all: check_prerequisites create_dirs run_tcl_scripts run_dc cleanup show_summary

# 帮助信息
.PHONY: help
help:
	@echo "用法: make [目标]"
	@echo ""
	@echo "Design Compiler 综合流程 Makefile"
	@echo ""
	@echo "目标:"
	@echo "  all          运行完整流程（默认）"
	@echo "  help         显示此帮助信息"
	@echo "  clean        清理所有生成的文件"
	@echo "  setup-only   仅运行设置阶段，不执行综合"
	@echo "  dc-only      仅运行Design Compiler（假设脚本已生成）"
	@echo "  no-cleanup   运行完整流程但跳过最终清理步骤"
	@echo ""
	@echo "示例:"
	@echo "  make                # 运行完整流程"
	@echo "  make clean          # 清理所有生成的文件"
	@echo "  make setup-only     # 仅生成TCL脚本"
	@echo "  make dc-only        # 仅运行DC综合"
	@echo ""

# 检查先决条件
.PHONY: check_prerequisites
check_prerequisites:
	$(call log_info,检查先决条件...)
	@# 检查必要的目录
	@for dir in exec setup; do \
		if [ ! -d "$(PROJECT_ROOT)/$$dir" ]; then \
			echo -e "$(RED)[ERROR]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - 缺少必要目录: $$dir" >&2; \
			exit 1; \
		fi; \
	done
	@# 检查必要的TCL脚本
	@for script in $(TCL_SCRIPTS); do \
		if [ ! -f "$(PROJECT_ROOT)/$$script" ]; then \
			echo -e "$(RED)[ERROR]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - 缺少必要脚本: $$script" >&2; \
			exit 1; \
		fi; \
	done
	@# 检查配置文件
	@for config in $(CONFIG_FILES); do \
		if [ ! -f "$(PROJECT_ROOT)/$$config" ]; then \
			echo -e "$(YELLOW)[WARN]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - 配置文件不存在: $$config (某些脚本可能需要此文件)"; \
		fi; \
	done
	$(call log_success,先决条件检查完成)

# 创建输出目录
.PHONY: create_dirs
create_dirs:
	$(call log_info,创建输出目录...)
	@for dir in $(OUTPUT_DIRS); do \
		if [ ! -d "$(PROJECT_ROOT)/$$dir" ]; then \
			mkdir -p "$(PROJECT_ROOT)/$$dir" || exit 1; \
			echo -e "$(BLUE)[INFO]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - 创建目录: $$dir"; \
		fi; \
	done
	$(call log_success,输出目录创建完成)

# 运行TCL脚本生成阶段
.PHONY: run_tcl_scripts
run_tcl_scripts: check_prerequisites create_dirs
	$(call log_info,=== 阶段1: 脚本生成 ===)
	@for script in $(TCL_SCRIPTS); do \
		echo -e "$(BLUE)[INFO]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - 运行脚本: $$script"; \
		script_name=$$(basename $$script .tcl); \
		log_file="$(PROJECT_ROOT)/log/$${script_name}_$(DATE).log"; \
		if tclsh "$(PROJECT_ROOT)/$$script" 2>&1 | tee "$$log_file"; then \
			echo -e "$(GREEN)[SUCCESS]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - 脚本执行完成: $$script"; \
		else \
			echo -e "$(RED)[ERROR]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - 脚本执行失败: $$script" >&2; \
			exit 1; \
		fi; \
	done
	$(call log_success,=== 阶段1完成: 所有TCL脚本执行完成 ===)

# 运行Design Compiler
.PHONY: run_dc
run_dc:
	$(call log_info,启动Design Compiler...)
	@if [ ! -f "$(PROJECT_ROOT)/work/script.tcl" ]; then \
		echo -e "$(RED)[ERROR]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - DC脚本不存在: $(PROJECT_ROOT)/work/script.tcl" >&2; \
		exit 1; \
	fi
	@if [ -z "$(DC_BIN)" ]; then \
		echo -e "$(RED)[ERROR]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - Design Compiler 未找到，请检查环境设置（PATH/许可等）" >&2; \
		exit 1; \
	fi
	$(call log_info,在work目录执行Design Compiler综合（$(DC_BIN) -f script.tcl）...)
	@cd "$(PROJECT_ROOT)/work" && \
	if $(DC_BIN) -f script.tcl 2>&1 | tee "$(PROJECT_ROOT)/log/dc_shell_$(DATE).log"; then \
		echo -e "$(GREEN)[SUCCESS]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - Design Compiler执行完成"; \
	else \
		echo -e "$(RED)[ERROR]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - Design Compiler执行失败，请检查日志: $(PROJECT_ROOT)/log/dc_shell_$(DATE).log" >&2; \
		exit 1; \
	fi

# 清理临时文件
.PHONY: cleanup
cleanup:
	$(call log_info,清理临时文件...)
	@find "$(PROJECT_ROOT)" -name "*.log.*" -type f -delete 2>/dev/null || true
	@find "$(PROJECT_ROOT)" -name "core.*" -type f -delete 2>/dev/null || true
	$(call log_success,清理完成)

# 显示结果摘要
.PHONY: show_summary
show_summary:
	$(call log_info,=== 综合流程执行摘要 ===)
	@echo ""
	@echo "时间戳: $(DATE)"
	@echo "项目目录: $(PROJECT_ROOT)"
	@echo ""
	@echo "生成的文件:"
	@if [ -d "$(PROJECT_ROOT)/output" ]; then \
		echo "  输出文件:"; \
		find "$(PROJECT_ROOT)/output" -type f -name "*$(DATE)*" 2>/dev/null | sed 's/^/    /' || echo "    (无输出文件)"; \
	fi
	@if [ -d "$(PROJECT_ROOT)/report" ]; then \
		echo "  报告文件:"; \
		find "$(PROJECT_ROOT)/report" -type f -name "*$(DATE)*" 2>/dev/null | sed 's/^/    /' || echo "    (无报告文件)"; \
	fi
	@if [ -d "$(PROJECT_ROOT)/log" ]; then \
		echo "  日志文件:"; \
		find "$(PROJECT_ROOT)/log" -type f -name "*$(DATE)*" 2>/dev/null | sed 's/^/    /' || echo "    (无日志文件)"; \
	fi
	@echo ""
	$(call log_success,综合流程完成！)

# 清理所有生成的文件
.PHONY: clean
clean:
	$(call log_info,清理所有生成的文件...)
	@for item in work output report log setup/rtl_design.lst; do \
		if [ -e "$(PROJECT_ROOT)/$$item" ]; then \
			rm -rf "$(PROJECT_ROOT)/$$item"; \
			echo -e "$(BLUE)[INFO]$(NC) $$(date '+%Y-%m-%d %H:%M:%S') - 删除: $$item"; \
		fi; \
	done
	$(call log_success,清理完成)

# 仅运行设置阶段
.PHONY: setup-only
setup-only: run_tcl_scripts
	$(call log_success,设置阶段完成（未运行DC综合）)

# 仅运行DC
.PHONY: dc-only
dc-only: check_prerequisites create_dirs run_dc cleanup show_summary

# 运行完整流程但不清理
.PHONY: no-cleanup
no-cleanup: check_prerequisites create_dirs run_tcl_scripts run_dc show_summary
	$(call log_info,跳过清理步骤)

# 防止删除中间文件
.PRECIOUS: $(OUTPUT_DIRS)

# 设置默认目标
.DEFAULT_GOAL := all