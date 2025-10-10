# Spyglass RTL Analysis Framework - Simplified Architecture
# Version: 3.0 - Fixed EOL and Architecture Issues

##############################################################################
# Configuration
##############################################################################

# Tool paths
SPYGLASS_HOME := $(shell command -v spyglass >/dev/null 2>&1 && \
                   dirname $$(dirname $$(which spyglass)) || \
                   echo "/tools/synopsys/spyglass/latest")
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
	@echo "  Spyglass RTL Analysis Framework v3.0 (Fixed Architecture)"
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
	@$(SG_SHELL) -version 2>/dev/null | head -1 || echo "Version check failed"
	@echo "Validation passed ✓"

##############################################################################
# Enhanced Setup - File List Generation with Error Handling
##############################################################################

setup: $(DIRS) $(RTL_FILELIST) $(INCLUDE_FILELIST)
	@echo "Setup completed ✓"

# Generate RTL file list (robust version)
$(RTL_FILELIST): | $(CONFIG_DIR)
	@echo "Generating RTL file list..."
	@echo "# RTL Files - Generated $(shell date)" > $@
	@echo "# Project: $(PROJECT_NAME)" >> $@
	@if [ -d "$(RTL_ROOT)" ]; then \
		find $(RTL_ROOT) -name "*.sv" -o -name "*.v" 2>/dev/null >> $@ || true; \
		file_count=$$(wc -l < $@ | tail -2 | head -1); \
		if [ "$$file_count" -eq 2 ]; then \
			echo "WARNING: No RTL files found in $(RTL_ROOT)"; \
			echo "# WARNING: No RTL files found" >> $@; \
		else \
			echo "  Found $$(($$file_count - 2)) RTL files"; \
		fi; \
	else \
		echo "ERROR: RTL_ROOT directory does not exist: $(RTL_ROOT)"; \
		echo "# ERROR: RTL_ROOT not found: $(RTL_ROOT)" >> $@; \
		exit 1; \
	fi
	@echo "Generated RTL filelist ✓"

# Generate include configuration (robust version)
$(INCLUDE_FILELIST): | $(CONFIG_DIR)
	@echo "Generating include configuration..."
	@echo "# Include Configuration - Generated $(shell date)" > $@
	@echo "# Project: $(PROJECT_NAME)" >> $@
	@echo "" >> $@
	@dir_count=0; \
	for dir in $(INCLUDE_DIRS); do \
		if [ -d "$$dir" ]; then \
			echo "+incdir+$$dir" >> $@; \
			echo "  ✓ Added include directory: $$dir"; \
			dir_count=$$((dir_count + 1)); \
		else \
			echo "  ⚠ Include directory not found (skipped): $$dir"; \
		fi; \
	done; \
	if [ $$dir_count -eq 0 ]; then \
		echo "  ⚠ WARNING: No include directories found"; \
		echo "# WARNING: No valid include directories" >> $@; \
	else \
		echo "  Added $$dir_count include directories"; \
	fi
	@echo "Generated include configuration ✓"


##############################################################################
# Analysis Targets
##############################################################################

run_lint: validate_env setup
	@echo "==================================================================="
	@echo "  Running Lint Analysis"
	@echo "  Project: $(PROJECT_NAME)"
	@echo "  Top: $(TOP_MODULES)"
	@echo "  Build: $(BUILD_TAG)"
	@echo "==================================================================="
	@$(SG_SHELL) -source $(SCRIPT_DIR)/run_spyglass.tcl lint 2>&1 | \
		tee $(LOG_DIR)/lint_$(TIMESTAMP).log
	@if [ $${PIPESTATUS[0]} -ne 0 ]; then \
		echo "ERROR: Lint failed. Check $(LOG_DIR)/lint_$(TIMESTAMP).log"; \
		exit 1; \
	fi
	@echo "Lint completed successfully ✓"

run_cdc: validate_env setup
	@echo "Running CDC Analysis..."
	@$(SG_SHELL) -source $(SCRIPT_DIR)/run_spyglass.tcl cdc 2>&1 | \
		tee $(LOG_DIR)/cdc_$(TIMESTAMP).log

run_rdc: validate_env setup
	@echo "Running RDC Analysis..."
	@$(SG_SHELL) -source $(SCRIPT_DIR)/run_spyglass.tcl rdc 2>&1 | \
		tee $(LOG_DIR)/rdc_$(TIMESTAMP).log

gui: setup
	@echo "Launching Spyglass GUI..."
	@cd $(RESULTS_DIR) && $(SG_GUI) -project $(PROJECT_NAME)_sg.prj &

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
	@echo "Results Size: $$(du -sh $(RESULTS_DIR) 2>/dev/null | cut -f1 || echo '0')"

clean:
	@echo "Cleaning..."
	@rm -rf $(RESULTS_DIR)/* $(LOG_DIR)/*
	@echo "Clean completed ✓"

distclean: clean
	@rm -rf $(RESULTS_DIR) $(LOG_DIR) $(CONFIG_DIR)/*.f
	@echo "Deep clean completed ✓"