#==============================================================================
# PrimeTime Analysis Framework - Complete Makefile
# Version: 3.0
# Author: Professional EDA Team
# Description: Complete flow control for PrimeTime STA and Power Analysis
#==============================================================================

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c

#==============================================================================
# CONFIGURATION VARIABLES
#==============================================================================

# Tool Settings
PT_SHELL ?= pt_shell
PT_VERSION_MIN ?= 2019.06

# Design Configuration
DESIGN_NAME ?= top_module
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)
RUN_NAME ?= run_$(TIMESTAMP)
RUN_DIR := ./runs/$(RUN_NAME)

# Input Files
NETLIST ?= ./netlist/$(DESIGN_NAME).v
VCD_FILE ?= ./simulation/$(DESIGN_NAME).vcd
SAIF_FILE ?= ./simulation/$(DESIGN_NAME).saif
SDC_FILE ?= ./constraints/$(DESIGN_NAME).sdc
SPEF_FILE ?= ./spef/$(DESIGN_NAME).spef

# Library Configuration
TARGET_LIBRARY ?= typical.lib
LINK_LIBRARY ?= "* $(TARGET_LIBRARY)"
SEARCH_PATH ?= ./libs ./netlist ./constraints

# Operating Conditions
VOLTAGE ?= 1.0
TEMPERATURE ?= 25
PROCESS ?= typical
CLOCK_PERIOD ?= 10.0

# Analysis Options
ACTIVITY_PRIORITY ?= VCD_FIRST
POWER_MODE ?= averaged
STA_MODE ?= graph_based

# Debug and Reporting Options
DEBUG ?= 0
VERBOSE ?= 0
STEP_MODE ?= 0
QUICK ?= 0
REPORT_HISTOGRAM ?= 1
REPORT_DETAILED ?= 1
EMAIL ?=

# Directory Structure
TCL_DIR := ./tcl
TCL_MODULES := $(TCL_DIR)/modules
TCL_FLOWS := $(TCL_DIR)/flows
TCL_CONFIG := $(TCL_DIR)/config

REPORT_DIR := $(RUN_DIR)/reports
LOG_DIR := $(RUN_DIR)/logs
CHECKPOINT_DIR := $(RUN_DIR)/checkpoints
CONFIG_DIR := $(RUN_DIR)/config
SCRIPT_DIR := $(RUN_DIR)/scripts

# Generated Files
RUN_CONFIG := $(CONFIG_DIR)/run_config.tcl
RUN_INFO := $(CONFIG_DIR)/run_info.txt

#==============================================================================
# COLORS FOR OUTPUT
#==============================================================================

RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

#==============================================================================
# MAIN TARGETS
#==============================================================================

.PHONY: all sta power full setup check clean help

# Default target
all: full

# Full analysis (STA + Power)
full: setup check
	@echo -e "$(BLUE)┌────────────────────────────────────────────────┐$(NC)"
	@echo -e "$(BLUE)│  Full Analysis: STA + Power                    │$(NC)"
	@echo -e "$(BLUE)│  Run: $(RUN_NAME)                              │$(NC)"
	@echo -e "$(BLUE)└────────────────────────────────────────────────┘$(NC)"
	@$(MAKE) generate_config
	@$(MAKE) run_full
	@$(MAKE) generate_summary
	@$(MAKE) final_message

# Static Timing Analysis only
sta: setup check
	@echo -e "$(BLUE)┌────────────────────────────────────────────────┐$(NC)"
	@echo -e "$(BLUE)│  Static Timing Analysis                        │$(NC)"
	@echo -e "$(BLUE)│  Run: $(RUN_NAME)                              │$(NC)"
	@echo -e "$(BLUE)└────────────────────────────────────────────────┘$(NC)"
	@$(MAKE) generate_config
	@$(MAKE) run_sta
	@$(MAKE) sta_summary
	@$(MAKE) final_message

# Power Analysis only
power: setup check
	@echo -e "$(BLUE)┌────────────────────────────────────────────────┐$(NC)"
	@echo -e "$(BLUE)│  Power Analysis                                │$(NC)"
	@echo -e "$(BLUE)│  Run: $(RUN_NAME)                              │$(NC)"
	@echo -e "$(BLUE)└────────────────────────────────────────────────┘$(NC)"
	@$(MAKE) generate_config
	@$(MAKE) run_power
	@$(MAKE) power_summary
	@$(MAKE) final_message

#==============================================================================
# SETUP AND VALIDATION TARGETS
#==============================================================================

setup: create_directories save_run_info
	@echo -e "$(GREEN)✓$(NC) Setup completed successfully"
	@echo "  Run directory: $(RUN_DIR)"
	@if [ "$(DEBUG)" = "1" ]; then \
		echo -e "  $(YELLOW)Debug mode: ENABLED$(NC)"; \
	fi
	@if [ "$(QUICK)" = "1" ]; then \
		echo -e "  $(YELLOW)Quick mode: ENABLED$(NC)"; \
	fi

create_directories:
	@echo "Creating directory structure..."
	@mkdir -p $(REPORT_DIR)/{timing,power,qor}
	@mkdir -p $(LOG_DIR) $(CHECKPOINT_DIR) $(CONFIG_DIR) $(SCRIPT_DIR)
	@mkdir -p ./archives

save_run_info:
	@echo "Saving run information..."
	@cat > $(RUN_INFO) << EOF
	Run Name: $(RUN_NAME)
	Timestamp: $(TIMESTAMP)
	Design: $(DESIGN_NAME)
	User: $(USER)
	Host: $(HOSTNAME)
	PWD: $(PWD)
	Command: make $(MAKECMDGOALS)
	EOF

check: check_tools check_files check_version
	@echo -e "$(GREEN)✓$(NC) All checks passed"

check_tools:
	@echo -n "Checking PrimeTime installation... "
	@which $(PT_SHELL) > /dev/null 2>&1 || \
		(echo -e "$(RED)ERROR: $(PT_SHELL) not found$(NC)" && exit 1)
	@echo -e "$(GREEN)OK$(NC) [$(shell which $(PT_SHELL))]"

check_files:
	@echo "Checking input files..."
	@test -f "$(NETLIST)" || \
		(echo -e "$(RED)ERROR: Netlist not found: $(NETLIST)$(NC)" && exit 1)
	@echo -e "  $(GREEN)✓$(NC) Netlist: $(NETLIST)"
	@test -f "$(SDC_FILE)" || \
		echo -e "  $(YELLOW)⚠$(NC) SDC file not found: $(SDC_FILE)"
	@test -f "$(VCD_FILE)" || test -f "$(SAIF_FILE)" || \
		echo -e "  $(YELLOW)⚠$(NC) No activity file found"
	@test -f "$(SPEF_FILE)" || \
		echo -e "  $(YELLOW)⚠$(NC) No SPEF file found"

check_version:
	@echo -n "Checking PrimeTime version... "
	@$(PT_SHELL) -f $(TCL_CONFIG)/version_check.tcl \
		-output_log_file $(LOG_DIR)/version_check.log 2>/dev/null || \
		echo -e "$(YELLOW)WARNING: Version check failed$(NC)"

#==============================================================================
# CONFIGURATION GENERATION
#==============================================================================

generate_config:
	@echo "Generating run configuration..."
	@$(PT_SHELL) -f $(TCL_CONFIG)/config_generator.tcl \
		-x "generate_config {$(RUN_CONFIG)} { \
			DESIGN_NAME {$(DESIGN_NAME)} \
			RUN_NAME {$(RUN_NAME)} \
			TIMESTAMP {$(TIMESTAMP)} \
			NETLIST {$(realpath $(NETLIST))} \
			SDC_FILE {$(shell realpath $(SDC_FILE) 2>/dev/null || echo "")} \
			VCD_FILE {$(shell realpath $(VCD_FILE) 2>/dev/null || echo "")} \
			SAIF_FILE {$(shell realpath $(SAIF_FILE) 2>/dev/null || echo "")} \
			SPEF_FILE {$(shell realpath $(SPEF_FILE) 2>/dev/null || echo "")} \
			TARGET_LIBRARY {$(TARGET_LIBRARY)} \
			LINK_LIBRARY {$(LINK_LIBRARY)} \
			SEARCH_PATH {$(SEARCH_PATH)} \
			VOLTAGE {$(VOLTAGE)} \
			TEMPERATURE {$(TEMPERATURE)} \
			PROCESS {$(PROCESS)} \
			CLOCK_PERIOD {$(CLOCK_PERIOD)} \
			ACTIVITY_PRIORITY {$(ACTIVITY_PRIORITY)} \
			POWER_MODE {$(POWER_MODE)} \
			STA_MODE {$(STA_MODE)} \
			REPORT_DIR {$(realpath $(REPORT_DIR))} \
			LOG_DIR {$(realpath $(LOG_DIR))} \
			CHECKPOINT_DIR {$(realpath $(CHECKPOINT_DIR))} \
			DEBUG {$(DEBUG)} \
			VERBOSE {$(VERBOSE)} \
			STEP_MODE {$(STEP_MODE)} \
			QUICK {$(QUICK)} \
			REPORT_HISTOGRAM {$(REPORT_HISTOGRAM)} \
			REPORT_DETAILED {$(REPORT_DETAILED)} \
			EMAIL {$(EMAIL)} \
			TCL_MODULES {$(realpath $(TCL_MODULES))} \
		}" -output_log_file $(LOG_DIR)/config_gen.log
	@echo -e "$(GREEN)✓$(NC) Configuration generated: $(RUN_CONFIG)"

#==============================================================================
# RUN TARGETS
#==============================================================================

run_sta:
	@echo "Running STA analysis..."
	@cd $(RUN_DIR) && \
		$(PT_SHELL) -f $(realpath $(TCL_FLOWS)/sta_flow.tcl) \
		-x "set ::RUN_CONFIG {$(realpath $(RUN_CONFIG))}" \
		2>&1 | tee $(LOG_DIR)/sta.log
	@if [ $${PIPESTATUS[0]} -eq 0 ]; then \
		echo -e "$(GREEN)✓$(NC) STA completed successfully"; \
	else \
		echo -e "$(RED)✗$(NC) STA failed - check $(LOG_DIR)/sta.log"; \
		exit 1; \
	fi

run_power:
	@echo "Running power analysis..."
	@cd $(RUN_DIR) && \
		$(PT_SHELL) -f $(realpath $(TCL_FLOWS)/power_flow.tcl) \
		-x "set ::RUN_CONFIG {$(realpath $(RUN_CONFIG))}" \
		2>&1 | tee $(LOG_DIR)/power.log
	@if [ $${PIPESTATUS[0]} -eq 0 ]; then \
		echo -e "$(GREEN)✓$(NC) Power analysis completed successfully"; \
	else \
		echo -e "$(RED)✗$(NC) Power analysis failed - check $(LOG_DIR)/power.log"; \
		exit 1; \
	fi

run_full:
	@echo "Running full analysis..."
	@cd $(RUN_DIR) && \
		$(PT_SHELL) -f $(realpath $(TCL_FLOWS)/full_flow.tcl) \
		-x "set ::RUN_CONFIG {$(realpath $(RUN_CONFIG))}" \
		2>&1 | tee $(LOG_DIR)/full.log
	@if [ $${PIPESTATUS[0]} -eq 0 ]; then \
		echo -e "$(GREEN)✓$(NC) Full analysis completed successfully"; \
	else \
		echo -e "$(RED)✗$(NC) Full analysis failed - check $(LOG_DIR)/full.log"; \
		exit 1; \
	fi

#==============================================================================
# SUMMARY AND REPORTING TARGETS
#==============================================================================

generate_summary:
	@echo ""
	@echo -e "$(BLUE)═══════════════════════════════════════════════$(NC)"
	@echo -e "$(BLUE) Analysis Complete$(NC)"
	@echo -e "$(BLUE)═══════════════════════════════════════════════$(NC)"
	@if [ -f "$(REPORT_DIR)/summary.txt" ]; then \
		cat $(REPORT_DIR)/summary.txt; \
	fi
	@echo ""
	@echo "Reports: $(REPORT_DIR)"
	@echo "Logs: $(LOG_DIR)"

sta_summary:
	@if [ -f "$(REPORT_DIR)/timing/summary.rpt" ]; then \
		echo ""; \
		echo -e "$(BLUE)=== STA Summary ===$(NC)"; \
		head -30 $(REPORT_DIR)/timing/summary.rpt; \
	fi

power_summary:
	@if [ -f "$(REPORT_DIR)/power/summary.rpt" ]; then \
		echo ""; \
		echo -e "$(BLUE)=== Power Summary ===$(NC)"; \
		head -30 $(REPORT_DIR)/power/summary.rpt; \
	fi

final_message:
	@echo ""
	@echo -e "$(GREEN)════════════════════════════════════════════════$(NC)"
	@echo -e "$(GREEN) ✓ Analysis Completed Successfully$(NC)"
	@echo -e "$(GREEN)════════════════════════════════════════════════$(NC)"
	@echo " Run: $(RUN_NAME)"
	@echo " Time: $(shell date)"
	@echo ""

#==============================================================================
# REGRESSION AND MULTI-CORNER ANALYSIS
#==============================================================================

regression:
	@echo -e "$(BLUE)Running multi-corner regression...$(NC)"
	@for corner in fast typical slow; do \
		echo -e "$(YELLOW)═══ Running $$corner corner ═══$(NC)"; \
		$(MAKE) full PROCESS=$$corner RUN_NAME=regr_$${corner}_$(TIMESTAMP) || exit 1; \
	done
	@echo -e "$(GREEN)✓$(NC) Regression complete"
	@$(MAKE) regression_summary

regression_summary:
	@echo ""
	@echo -e "$(BLUE)═══ Regression Summary ═══$(NC)"
	@for dir in ./runs/regr_*_$(TIMESTAMP); do \
		if [ -d "$$dir" ]; then \
			corner=$$(basename $$dir | cut -d_ -f2); \
			echo -e "$(YELLOW)$$corner corner:$(NC)"; \
			grep -h "WNS\|TNS" $$dir/reports/summary.txt 2>/dev/null || echo "  No timing data"; \
			grep -h "Total Power" $$dir/reports/summary.txt 2>/dev/null || echo "  No power data"; \
		fi; \
	done

#==============================================================================
# DEBUG AND DEVELOPMENT TARGETS
#==============================================================================

debug: DEBUG=1
debug: VERBOSE=1
debug: full
	@echo -e "$(YELLOW)Debug run complete with enhanced logging$(NC)"

step: STEP_MODE=1
step: DEBUG=1
step: full
	@echo -e "$(YELLOW)Step-by-step run complete$(NC)"

interactive:
	@echo -e "$(BLUE)Starting interactive PrimeTime session...$(NC)"
	@$(MAKE) setup generate_config
	@cd $(RUN_DIR) && $(PT_SHELL) -gui -x "source $(realpath $(RUN_CONFIG))"

quick-sta: QUICK=1
quick-sta: VERBOSE=0
quick-sta: REPORT_DETAILED=0
quick-sta: sta
	@echo -e "$(GREEN)Quick STA complete$(NC)"

#==============================================================================
# BATCH AND COMPARISON TARGETS
#==============================================================================

batch:
	@if [ -z "$(DESIGNS)" ]; then \
		echo -e "$(RED)Usage: make batch DESIGNS='design1 design2 design3'$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(BLUE)Running batch analysis...$(NC)"
	@for design in $(DESIGNS); do \
		echo -e "$(YELLOW)═══ Processing $$design ═══$(NC)"; \
		$(MAKE) full DESIGN_NAME=$$design RUN_NAME=batch_$${design}_$(TIMESTAMP); \
	done
	@echo -e "$(GREEN)✓$(NC) Batch processing complete"

compare-runs:
	@if [ -z "$(RUN1)" ] || [ -z "$(RUN2)" ]; then \
		echo -e "$(RED)Usage: make compare-runs RUN1=run_xxx RUN2=run_yyy$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(BLUE)Comparing $(RUN1) vs $(RUN2):$(NC)"
	@echo -e "$(YELLOW)═══ Timing Comparison ═══$(NC)"
	@diff -u ./runs/$(RUN1)/reports/timing/summary.rpt \
	         ./runs/$(RUN2)/reports/timing/summary.rpt | head -50 || true
	@echo -e "$(YELLOW)═══ Power Comparison ═══$(NC)"
	@diff -u ./runs/$(RUN1)/reports/power/summary.rpt \
	         ./runs/$(RUN2)/reports/power/summary.rpt | head -50 || true

#==============================================================================
# UTILITY TARGETS
#==============================================================================

list-runs:
	@echo -e "$(BLUE)Available runs:$(NC)"
	@ls -lt ./runs 2>/dev/null | head -20 || echo "No runs found"

latest:
	@LATEST=$$(ls -t ./runs | head -1); \
	if [ -n "$$LATEST" ]; then \
		echo -e "$(BLUE)Latest run: $$LATEST$(NC)"; \
		echo "Reports:"; \
		find ./runs/$$LATEST/reports -name "*.rpt" -type f | head -10; \
	else \
		echo "No runs found"; \
	fi

stats:
	@echo -e "$(BLUE)═══ Analysis Statistics ═══$(NC)"
	@echo "Total runs: $$(ls -d ./runs/* 2>/dev/null | wc -l)"
	@echo "Disk usage: $$(du -sh ./runs 2>/dev/null | cut -f1)"
	@LATEST=$$(ls -t ./runs | head -1); \
	if [ -n "$$LATEST" ]; then \
		echo "Latest run: $$LATEST"; \
		echo "  Reports: $$(find ./runs/$$LATEST -name '*.rpt' | wc -l)"; \
		echo "  Logs: $$(find ./runs/$$LATEST -name '*.log' | wc -l)"; \
		echo "  Size: $$(du -sh ./runs/$$LATEST | cut -f1)"; \
	fi

archive:
	@if [ -z "$(RUN)" ]; then \
		echo -e "$(RED)Usage: make archive RUN=run_name$(NC)"; \
		exit 1; \
	fi
	@echo "Archiving $(RUN)..."
	@tar czf ./archives/$(RUN).tar.gz -C ./runs $(RUN)
	@echo -e "$(GREEN)✓$(NC) Archived to ./archives/$(RUN).tar.gz"

extract:
	@if [ -z "$(ARCHIVE)" ]; then \
		echo -e "$(RED)Usage: make extract ARCHIVE=archive_name$(NC)"; \
		exit 1; \
	fi
	@echo "Extracting $(ARCHIVE)..."
	@tar xzf ./archives/$(ARCHIVE).tar.gz -C ./runs
	@echo -e "$(GREEN)✓$(NC) Extracted to ./runs/"

#==============================================================================
# CLEAN TARGETS
#==============================================================================

clean:
	@echo -e "$(YELLOW)This will remove run: $(RUN_NAME)$(NC)"
	@read -p "Continue? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		rm -rf $(RUN_DIR); \
		echo -e "$(GREEN)Run removed$(NC)"; \
	else \
		echo "Cancelled"; \
	fi

clean-latest:
	@LATEST=$$(ls -t ./runs | head -1); \
	if [ -n "$$LATEST" ]; then \
		echo -e "$(YELLOW)Remove latest run: $$LATEST?$(NC)"; \
		read -p "[y/N]: " confirm; \
		if [ "$$confirm" = "y" ]; then \
			rm -rf ./runs/$$LATEST; \
			echo -e "$(GREEN)Removed$(NC)"; \
		fi; \
	else \
		echo "No runs found"; \
	fi

clean-all:
	@echo -e "$(RED)WARNING: This will remove ALL runs!$(NC)"
	@read -p "Type 'DELETE ALL' to confirm: " confirm; \
	if [ "$$confirm" = "DELETE ALL" ]; then \
		rm -rf ./runs; \
		mkdir ./runs; \
		echo -e "$(GREEN)All runs removed$(NC)"; \
	else \
		echo "Cancelled"; \
	fi

#==============================================================================
# HELP TARGET
#==============================================================================

help:
	@echo ""
	@echo -e "$(BLUE)╔══════════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(BLUE)║  PrimeTime Analysis Framework v3.0                      ║$(NC)"
	@echo -e "$(BLUE)║  Complete STA and Power Analysis Solution               ║$(NC)"
	@echo -e "$(BLUE)╚══════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo -e "$(GREEN)USAGE:$(NC)"
	@echo "  make [target] [VARIABLE=value]"
	@echo ""
	@echo -e "$(GREEN)MAIN TARGETS:$(NC)"
	@echo "  all/full    - Run complete analysis (STA + Power)"
	@echo "  sta         - Run Static Timing Analysis only"
	@echo "  power       - Run Power Analysis only"
	@echo ""
	@echo -e "$(GREEN)DEBUG TARGETS:$(NC)"
	@echo "  debug       - Run with debug mode enabled"
	@echo "  step        - Run with step-by-step mode"
	@echo "  interactive - Start interactive PT session"
	@echo "  quick-sta   - Quick STA with minimal reports"
	@echo ""
	@echo -e "$(GREEN)BATCH TARGETS:$(NC)"
	@echo "  regression  - Multi-corner analysis (fast/typical/slow)"
	@echo "  batch       - Process multiple designs"
	@echo ""
	@echo -e "$(GREEN)UTILITY TARGETS:$(NC)"
	@echo "  list-runs   - List all available runs"
	@echo "  latest      - Show latest run and reports"
	@echo "  stats       - Show statistics"
	@echo "  compare-runs- Compare two runs (RUN1=xxx RUN2=yyy)"
	@echo "  archive     - Archive a run (RUN=run_name)"
	@echo "  extract     - Extract archived run (ARCHIVE=name)"
	@echo ""
	@echo -e "$(GREEN)CLEAN TARGETS:$(NC)"
	@echo "  clean       - Remove current run"
	@echo "  clean-latest- Remove latest run"
	@echo "  clean-all   - Remove all runs (requires confirmation)"
	@echo ""
	@echo -e "$(GREEN)KEY VARIABLES:$(NC)"
	@echo "  DESIGN_NAME    - Top module name (default: top_module)"
	@echo "  RUN_NAME       - Custom run name (default: run_TIMESTAMP)"
	@echo "  DEBUG          - Enable debug mode (0/1)"
	@echo "  VERBOSE        - Enable verbose output (0/1)"
	@echo "  STEP_MODE      - Enable step-by-step execution (0/1)"
	@echo "  QUICK          - Quick mode with minimal reports (0/1)"
	@echo ""
	@echo -e "$(GREEN)FILE VARIABLES:$(NC)"
	@echo "  NETLIST        - Path to netlist file"
	@echo "  SDC_FILE       - Path to SDC constraints"
	@echo "  VCD_FILE       - Path to VCD activity file"
	@echo "  SAIF_FILE      - Path to SAIF activity file"
	@echo "  SPEF_FILE      - Path to SPEF parasitics"
	@echo ""
	@echo -e "$(GREEN)OPERATING CONDITIONS:$(NC)"
	@echo "  VOLTAGE        - Operating voltage (default: 1.0)"
	@echo "  TEMPERATURE    - Operating temperature (default: 25)"
	@echo "  PROCESS        - Process corner (default: typical)"
	@echo "  CLOCK_PERIOD   - Clock period in ns (default: 10.0)"
	@echo ""
	@echo -e "$(GREEN)EXAMPLES:$(NC)"
	@echo "  make sta DESIGN_NAME=cpu_core"
	@echo "  make power DEBUG=1 VCD_FILE=./sim/test.vcd"
	@echo "  make regression DESIGN_NAME=my_chip"
	@echo "  make batch DESIGNS='cpu gpu dsp'"
	@echo "  make compare-runs RUN1=run_20240101 RUN2=run_20240102"
	@echo ""
	@echo -e "$(BLUE)For more information, see docs/user_guide.md$(NC)"
	@echo ""

#==============================================================================
# SPECIAL TARGETS
#==============================================================================

.PHONY: test
test:
	@echo -e "$(BLUE)Running self-test...$(NC)"
	@echo "Checking directory structure..."
	@test -d $(TCL_MODULES) || (echo -e "$(RED)ERROR: TCL modules not found$(NC)" && exit 1)
	@test -d $(TCL_FLOWS) || (echo -e "$(RED)ERROR: TCL flows not found$(NC)" && exit 1)
	@test -d $(TCL_CONFIG) || (echo -e "$(RED)ERROR: TCL config not found$(NC)" && exit 1)
	@echo -e "$(GREEN)✓$(NC) Directory structure OK"
	@echo "Checking TCL modules..."
	@for i in {00..10}; do \
		test -f $(TCL_MODULES)/$${i}_*.tcl || echo -e "$(YELLOW)WARNING: Module $$i not found$(NC)"; \
	done
	@echo -e "$(GREEN)✓$(NC) TCL modules OK"
	@echo -e "$(GREEN)Self-test passed$(NC)"

.PHONY: install
install:
	@echo -e "$(BLUE)Installing PrimeTime Analysis Framework...$(NC)"
	@mkdir -p tcl/{modules,flows,config}
	@mkdir -p {libs,netlist,constraints,simulation,spef,archives,docs,examples}
	@echo -e "$(GREEN)✓$(NC) Directory structure created"
	@echo "Please copy TCL modules to tcl/modules/"
	@echo "Please copy flow scripts to tcl/flows/"
	@echo "Installation complete!"

.PHONY: version
version:
	@echo "PrimeTime Analysis Framework"
	@echo "Version: 3.0"
	@echo "Date: $(shell date)"
	@echo "PrimeTime: $(shell $(PT_SHELL) -version 2>/dev/null | head -1 || echo 'Not found')"

#==============================================================================
# DEPENDENCY MANAGEMENT
#==============================================================================

# Ensure TCL modules exist before running flows
$(TCL_FLOWS)/%.tcl: $(TCL_MODULES)
$(RUN_CONFIG): generate_config

#==============================================================================
# END OF MAKEFILE
#==============================================================================