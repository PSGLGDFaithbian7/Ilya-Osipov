# Spyglass RTL Analysis Framework - P-2019 Compatible Version
# Version: 3.1 - Fixed for Spyglass P-2019.06

##############################################################################
# Configuration
##############################################################################

# Tool paths
SPYGLASS_HOME := $(shell command -v spyglass >/dev/null 2>&1 && \
                   dirname $$(dirname $$(which spyglass)) || \
                   echo "/NAS/cad/synopsys/spyglass/P-2019.06-SP2-17/SPYGLASS_HOME")
SG_SHELL      := $(SPYGLASS_HOME)/bin/sg_shell

# Validate tool
ifeq ($(wildcard $(SG_SHELL)),)
$(error Spyglass not found. Set SPYGLASS_HOME or add to PATH)
endif

# Project configuration
PROJECT_NAME  ?= rtl_project
TOP_MODULES   ?= top_module
RTL_ROOT      ?= ./rtl
INCLUDE_DIRS  ?= ./include ./rtl/include
CONFIG_DIR    ?= ./config
SCRIPT_DIR    ?= ./scripts
RESULTS_DIR   ?= ./results
LOG_DIR       ?= ./logs

# Analysis configuration
SG_WAIVER_FILE ?= $(CONFIG_DIR)/waivers.awl
REUSE          ?= 0
DEBUG          ?= 0

# Build tracking
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TAG  := $(GIT_COMMIT)_$(TIMESTAMP)

# File lists
RTL_FILELIST     := $(CONFIG_DIR)/rtl_files.f
INCLUDE_FILELIST := $(CONFIG_DIR)/include_files.f

# Export ALL variables for TCL scripts
export PROJECT_NAME TOP_MODULES RTL_ROOT INCLUDE_DIRS CONFIG_DIR SCRIPT_DIR
export RESULTS_DIR LOG_DIR TIMESTAMP BUILD_TAG SG_WAIVER_FILE REUSE DEBUG
export RTL_FILELIST INCLUDE_FILELIST

##############################################################################
# Directory Setup
##############################################################################

DIRS := $(CONFIG_DIR) $(SCRIPT_DIR) $(RESULTS_DIR) $(LOG_DIR) \
        $(RESULTS_DIR)/lint $(RESULTS_DIR)/cdc $(RESULTS_DIR)/rdc

$(DIRS):
	@mkdir -p $@

##############################################################################
# Main Targets
##############################################################################

.PHONY: all help setup run_lint run_cdc validate_env clean status

all: validate_env setup run_lint

help:
	@echo "==================================================================="
	@echo "  Spyglass RTL Analysis Framework v3.1 (P-2019 Compatible)"
	@echo "==================================================================="
	@echo ""
	@echo "Main Targets:"
	@echo "  all         - Run complete lint analysis"
	@echo "  run_lint    - Lint analysis"
	@echo "  run_cdc     - CDC analysis"
	@echo "  run_rdc     - RDC analysis"
	@echo "  gui         - Launch Spyglass GUI"
	@echo ""
	@echo "Utility:"
	@echo "  setup       - Create directories and file lists"
	@echo "  validate_env- Check tool installation"
	@echo "  status      - Show project status"
	@echo "  clean       - Remove results"
	@echo ""
	@echo "Configuration:"
	@echo "  PROJECT_NAME = $(PROJECT_NAME)"
	@echo "  TOP_MODULES  = $(TOP_MODULES)"
	@echo "  RTL_ROOT     = $(RTL_ROOT)"
	@echo "  BUILD_TAG    = $(BUILD_TAG)"
	@echo ""
	@echo "Examples:"
	@echo "  make run_lint TOP_MODULES=\"cpu mmu\""
	@echo "  make run_cdc REUSE=1 DEBUG=1"

##############################################################################
# Validation
##############################################################################

validate_env:
	@echo "Validating environment..."
	@test -f $(SG_SHELL) || (echo "ERROR: sg_shell not found"; exit 1)
	@echo "Spyglass: $(SG_SHELL)"
	@echo "Version: $$($(SG_SHELL) -version 2>/dev/null | head -1 || echo 'Unknown')"
	@echo "Validation passed ✓"

##############################################################################
# Setup - File List Generation
##############################################################################

setup: $(DIRS) $(RTL_FILELIST) $(INCLUDE_FILELIST)
	@echo "Setup completed ✓"

# Generate RTL file list
$(RTL_FILELIST): | $(CONFIG_DIR)
	@echo "Generating RTL file list..."
	@echo "# RTL Files - Generated $(shell date)" > $@
	@echo "# Project: $(PROJECT_NAME)" >> $@
	@if [ -d "$(RTL_ROOT)" ]; then \
		find $(RTL_ROOT) -name "*.sv" -o -name "*.v" 2>/dev/null >> $@ || true; \
		file_count=$$(grep -v '^#' $@ | wc -l); \
		echo "  Found $$file_count RTL files"; \
		if [ $$file_count -eq 0 ]; then \
			echo "  WARNING: No RTL files found in $(RTL_ROOT)"; \
		fi; \
	else \
		echo "ERROR: RTL_ROOT does not exist: $(RTL_ROOT)"; \
		exit 1; \
	fi
	@echo "Generated RTL filelist ✓"

# Generate include configuration (with error tolerance)
$(INCLUDE_FILELIST): | $(CONFIG_DIR)
	@echo "Generating include configuration..."
	@echo "# Include Dirs - Generated $(shell date)" > $@
	@echo "# Project: $(PROJECT_NAME)" >> $@
	@dir_found=0; \
	for dir in $(INCLUDE_DIRS); do \
		if [ -d "$$dir" ]; then \
			echo "+incdir+$$dir" >> $@; \
			echo "  Added: $$dir"; \
			dir_found=1; \
		else \
			echo "  Skipped (not found): $$dir"; \
		fi; \
	done; \
	if [ $$dir_found -eq 0 ]; then \
		echo "  WARNING: No include directories found"; \
		echo "# No include directories available" >> $@; \
	fi
	@echo "Generated include configuration ✓"

##############################################################################
# Analysis Targets - P-2019 Compatible (Environment Variable Mode)
##############################################################################

run_lint: validate_env setup
	@echo "==================================================================="
	@echo "  Running Lint Analysis"
	@echo "  Project: $(PROJECT_NAME)"
	@echo "  Top Modules: $(TOP_MODULES)"
	@echo "  Build Tag: $(BUILD_TAG)"
	@echo "  Timestamp: $(TIMESTAMP)"
	@echo "==================================================================="
	@mkdir -p $(RESULTS_DIR)/lint $(LOG_DIR)
	@echo "Invoking Spyglass (P-2019 mode)..."
	@SG_GOAL=lint $(SG_SHELL) -tcl $(SCRIPT_DIR)/run_spyglass.tcl 2>&1 | \
		tee $(LOG_DIR)/lint_$(TIMESTAMP).log; \
	exit_code=$${PIPESTATUS[0]}; \
	echo ""; \
	echo "Spyglass exited with code: $$exit_code"; \
	if [ $$exit_code -ne 0 ]; then \
		echo "ERROR: Lint analysis failed"; \
		echo "Check log: $(LOG_DIR)/lint_$(TIMESTAMP).log"; \
		exit 1; \
	fi
	@echo ""
	@echo "Checking for generated reports..."
	@if [ -d "$(RESULTS_DIR)/lint" ]; then \
		report_count=$$(find $(RESULTS_DIR)/lint -name "*.rpt" 2>/dev/null | wc -l); \
		echo "Found $$report_count report files"; \
		if [ $$report_count -gt 0 ]; then \
			echo "Report files:"; \
			find $(RESULTS_DIR)/lint -name "*.rpt" -exec ls -lh {} \;; \
		else \
			echo "WARNING: No .rpt files found in $(RESULTS_DIR)/lint"; \
		fi; \
	fi
	@echo "=== Lint Analysis Completed Successfully ==="

run_cdc: validate_env setup
	@echo "=== Running CDC Analysis ==="
	@mkdir -p $(RESULTS_DIR)/cdc $(LOG_DIR)
	@SG_GOAL=cdc $(SG_SHELL) -tcl $(SCRIPT_DIR)/run_spyglass.tcl 2>&1 | \
		tee $(LOG_DIR)/cdc_$(TIMESTAMP).log; \
	exit_code=$${PIPESTATUS[0]}; \
	if [ $$exit_code -ne 0 ]; then \
		echo "ERROR: CDC analysis failed"; exit 1; \
	fi

run_rdc: validate_env setup
	@echo "=== Running RDC Analysis ==="
	@mkdir -p $(RESULTS_DIR)/rdc $(LOG_DIR)
	@SG_GOAL=rdc $(SG_SHELL) -tcl $(SCRIPT_DIR)/run_spyglass.tcl 2>&1 | \
		tee $(LOG_DIR)/rdc_$(TIMESTAMP).log; \
	exit_code=$${PIPESTATUS[0]}; \
	if [ $$exit_code -ne 0 ]; then \
		echo "ERROR: RDC analysis failed"; exit 1; \
	fi
##############################################################################
# View Reports
##############################################################################

.PHONY: view_lint view_cdc view_rdc

view_lint:
	@latest=$$(ls -td $(RESULTS_DIR)/lint/run_* 2>/dev/null | head -1); \
	if [ -n "$$latest" ]; then \
		html="$$latest/index.html"; \
		if [ -f "$$html" ]; then \
			echo "Opening lint report: $$html"; \
			firefox "$$html" & \
		else \
			echo "HTML report not found"; \
		fi; \
	else \
		echo "No lint results found"; \
	fi

view_cdc:
	@latest=$$(ls -td $(RESULTS_DIR)/cdc/run_* 2>/dev/null | head -1); \
	if [ -n "$$latest" ]; then \
		firefox "$$latest/index.html" & \
	fi

view_rdc:
	@latest=$$(ls -td $(RESULTS_DIR)/rdc/run_* 2>/dev/null | head -1); \
	if [ -n "$$latest" ]; then \
		firefox "$$latest/index.html" & \
	fi


##############################################################################
# Utilities
##############################################################################

status:
	@echo "=== Project Status ==="
	@echo "Project:      $(PROJECT_NAME)"
	@echo "Build Tag:    $(BUILD_TAG)"
	@echo "RTL Root:     $(RTL_ROOT)"
	@echo "Top Modules:  $(TOP_MODULES)"
	@echo "Spyglass:     $(SG_SHELL)"
	@echo "Last Lint:    $$(ls -t $(LOG_DIR)/lint_*.log 2>/dev/null | head -1 || echo 'None')"
	@if [ -d "$(RESULTS_DIR)" ]; then \
		echo "Results Size: $$(du -sh $(RESULTS_DIR) 2>/dev/null | cut -f1)"; \
		echo "Report Count: $$(find $(RESULTS_DIR) -name '*.rpt' 2>/dev/null | wc -l)"; \
	fi

clean:
	@echo "Cleaning..."
	@rm -rf $(RESULTS_DIR)/* $(LOG_DIR)/*
	@echo "Clean completed ✓"

distclean: clean
	@rm -rf $(RESULTS_DIR) $(LOG_DIR) $(CONFIG_DIR)/*.f
	@echo "Deep clean completed ✓"
# 清理旧的运行（保留最近N次）
clean_old_runs:
	@echo "Cleaning old run directories (keeping latest 5)..."
	@for goal in lint cdc rdc; do \
		if [ -d "$(RESULTS_DIR)/$$goal" ]; then \
			cd $(RESULTS_DIR)/$$goal && \
			ls -t | tail -n +6 | xargs -r rm -rf; \
		fi; \
	done
	@echo "Old runs cleaned ✓"

debug:
	@echo "=== Debug Information ==="
	@echo "SG_SHELL: $(SG_SHELL)"
	@$(SG_SHELL) -help 2>&1 | grep -E '\-tcl|\-source|\-shell|\-batch' || echo "No script options found"
	@echo ""
	@echo "Environment Variables:"
	@env | grep -E "PROJECT_NAME|TOP_MODULES|RESULTS_DIR|TIMESTAMP"
	@echo ""
	@echo "Directory Structure:"
	@find results -type d 2>/dev/null | head -20
