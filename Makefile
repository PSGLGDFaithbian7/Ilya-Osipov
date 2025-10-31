# =============================================================================
# Industrial-Grade Design Compiler Synthesis System - Final Version
# Author: EDA Team
# Version: 2.0
# =============================================================================

SHELL := /bin/bash
PROJECT_ROOT := $(shell pwd)
TIMESTAMP := $(shell date "+%Y%m%d_%H%M%S")

# Configuration
CONFIG_FILE ?= config/project_config.yaml
DC_SHELL ?= dc_shell-t
TCLSH ?= tclsh

# Extract info from config
TOP_MODULE := $(shell grep "top_module:" $(CONFIG_FILE) 2>/dev/null | awk '{print $$2}' | tr -d '"')

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
CYAN := \033[0;36m
MAGENTA := \033[0;35m
NC := \033[0m

# Directories
WORK_DIR := work
OUTPUT_DIR := output/$(TIMESTAMP)
REPORT_DIR := report/$(TIMESTAMP)
LOG_DIR := log

# Export for TCL scripts
export CONFIG_FILE TIMESTAMP TOP_MODULE PROJECT_ROOT

# =============================================================================
# Main Targets
# =============================================================================

.PHONY: all
all: banner validate synthesize analyze report summary

.PHONY: banner
banner:
	@echo -e "$(CYAN)╔════════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(CYAN)║     Industrial Grade DC Synthesis System v2.0         ║$(NC)"
	@echo -e "$(CYAN)║          Preserving All Original Features             ║$(NC)"
	@echo -e "$(CYAN)╚════════════════════════════════════════════════════════╝$(NC)"

.PHONY: synthesize
synthesize: check prepare
	@echo -e "$(CYAN)╔════════════════════════════════════════╗$(NC)"
	@echo -e "$(CYAN)║     Starting Synthesis Flow            ║$(NC)"
	@echo -e "$(CYAN)╚════════════════════════════════════════╝$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Module: $(TOP_MODULE)"
	@echo -e "$(BLUE)[INFO]$(NC) Config: $(CONFIG_FILE)"
	@echo -e "$(BLUE)[INFO]$(NC) Timestamp: $(TIMESTAMP)"
	@mkdir -p $(LOG_DIR)
	@cd $(WORK_DIR) && $(DC_SHELL) -f ../scripts/synthesis_main.tcl \
		2>&1 | tee ../$(LOG_DIR)/synthesis_$(TIMESTAMP).log
	@if [ $${PIPESTATUS[0]} -ne 0 ]; then \
		echo -e "$(RED)[ERROR]$(NC) Synthesis failed!"; \
		$(MAKE) error_analysis; \
		exit 1; \
	fi
	@echo $(TIMESTAMP) > $(WORK_DIR)/.last_synthesis
	@echo -e "$(GREEN)[SUCCESS]$(NC) Synthesis completed successfully"

.PHONY: validate
validate:
	@echo -e "$(BLUE)[INFO]$(NC) Validating configuration..."
	@$(TCLSH) scripts/tools/config_validator.tcl $(CONFIG_FILE)
	@if [ $$? -ne 0 ]; then \
		echo -e "$(RED)[ERROR]$(NC) Configuration validation failed!"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)[SUCCESS]$(NC) Configuration valid"

.PHONY: check
check:
	@echo -e "$(BLUE)[INFO]$(NC) Checking prerequisites..."
	@# Check for Design Compiler
	@if ! command -v $(DC_SHELL) &> /dev/null; then \
		echo -e "$(RED)[ERROR]$(NC) Design Compiler not found: $(DC_SHELL)"; \
		exit 1; \
	fi
	@# Check configuration file
	@if [ ! -f "$(CONFIG_FILE)" ]; then \
		echo -e "$(RED)[ERROR]$(NC) Configuration file not found: $(CONFIG_FILE)"; \
		echo -e "$(YELLOW)[HINT]$(NC) Run 'make init' to create default configuration"; \
		exit 1; \
	fi
	@# Check TCL scripts
	@for script in scripts/*.tcl scripts/lib/*.tcl; do \
		if [ -f "$$script" ]; then \
			$(TCLSH) scripts/tools/syntax_check.tcl $$script || true; \
		fi; \
	done
	@echo -e "$(GREEN)[SUCCESS]$(NC) All prerequisites met"

.PHONY: prepare
prepare:
	@echo -e "$(BLUE)[INFO]$(NC) Preparing work environment..."
	@mkdir -p $(WORK_DIR)
	@mkdir -p $(OUTPUT_DIR)/{netlist,constraints,parasitics}
	@mkdir -p $(REPORT_DIR)/{timing,area,power,clock,qor,checks,analysis}
	@mkdir -p $(LOG_DIR)
	@# Generate RTL file list using the original recursive finder
	@$(TCLSH) scripts/lib/generate_rtl_list.tcl
	@echo -e "$(GREEN)[SUCCESS]$(NC) Environment ready"

.PHONY: analyze
analyze:
	@echo -e "$(BLUE)[INFO]$(NC) Analyzing synthesis results..."
	@$(TCLSH) scripts/tools/qor_analyzer.tcl \
		--report-dir $(REPORT_DIR) \
		--output $(REPORT_DIR)/analysis/qor_analysis.html
	@echo -e "$(GREEN)[SUCCESS]$(NC) Analysis complete"
	@echo -e "$(YELLOW)[INFO]$(NC) Open $(REPORT_DIR)/analysis/qor_analysis.html to view results"

.PHONY: report
report:
	@echo -e "$(BLUE)[INFO]$(NC) Generating comprehensive reports..."
	@if [ -f "$(OUTPUT_DIR)/netlist/$(TOP_MODULE).ddc" ]; then \
		cd $(WORK_DIR) && $(DC_SHELL) -f ../scripts/generate_all_reports.tcl \
			2>&1 | tee ../$(LOG_DIR)/reports_$(TIMESTAMP).log; \
	else \
		echo -e "$(YELLOW)[WARN]$(NC) No compiled design found, skipping reports"; \
	fi

.PHONY: summary
summary:
	@echo -e "\n$(CYAN)╔════════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(CYAN)║              SYNTHESIS FLOW SUMMARY                     ║$(NC)"
	@echo -e "$(CYAN)╠════════════════════════════════════════════════════════╣$(NC)"
	@echo -e "$(CYAN)║$(NC) Project:   $(TOP_MODULE)"
	@echo -e "$(CYAN)║$(NC) Timestamp: $(TIMESTAMP)"
	@echo -e "$(CYAN)║$(NC) Config:    $(CONFIG_FILE)"
	@echo -e "$(CYAN)╟────────────────────────────────────────────────────────╢$(NC)"
	@# Extract QoR summary
	@if [ -f "$(REPORT_DIR)/qor/qor_summary.txt" ]; then \
		cat $(REPORT_DIR)/qor/qor_summary.txt | sed 's/^/$(CYAN)║$(NC) /'; \
	fi
	@echo -e "$(CYAN)╟────────────────────────────────────────────────────────╢$(NC)"
	@echo -e "$(CYAN)║$(NC) Output Files:"
	@if [ -d "$(OUTPUT_DIR)" ]; then \
		find $(OUTPUT_DIR) -type f \( -name "*.v" -o -name "*.sdc" \) | head -5 | sed 's/^/$(CYAN)║$(NC)   /'; \
	fi
	@echo -e "$(CYAN)╟────────────────────────────────────────────────────────╢$(NC)"
	@echo -e "$(CYAN)║$(NC) Key Reports:"
	@echo -e "$(CYAN)║$(NC)   Timing: $(REPORT_DIR)/timing/"
	@echo -e "$(CYAN)║$(NC)   Area:   $(REPORT_DIR)/area/"
	@echo -e "$(CYAN)║$(NC)   Power:  $(REPORT_DIR)/power/"
	@echo -e "$(CYAN)║$(NC)   QoR:    $(REPORT_DIR)/analysis/qor_analysis.html"
	@echo -e "$(CYAN)╚════════════════════════════════════════════════════════╝$(NC)\n"

.PHONY: compare
compare:
	@echo -e "$(BLUE)[INFO]$(NC) Comparing synthesis runs..."
	@RUN1=$$(ls -td report/*/ 2>/dev/null | head -1); \
	RUN2=$$(ls -td report/*/ 2>/dev/null | head -2 | tail -1); \
	if [ -z "$$RUN1" ] || [ -z "$$RUN2" ]; then \
		echo -e "$(RED)[ERROR]$(NC) Need at least 2 synthesis runs to compare"; \
		exit 1; \
	fi; \
	$(TCLSH) scripts/tools/compare_runs.tcl $$RUN1 $$RUN2 $(REPORT_DIR)/comparison.txt
	@echo -e "$(GREEN)[SUCCESS]$(NC) Comparison saved to $(REPORT_DIR)/comparison.txt"

.PHONY: monitor
monitor:
	@echo -e "$(BLUE)[INFO]$(NC) Starting synthesis monitor..."
	@watch -n 2 "tail -20 $(LOG_DIR)/synthesis_$(TIMESTAMP).log 2>/dev/null || echo 'Waiting for synthesis to start...'"

.PHONY: init
init:
	@echo -e "$(BLUE)[INFO]$(NC) Initializing project structure..."
	@mkdir -p config rtl/{src,include,tb} lib scripts/{lib,tools,templates}
	@mkdir -p work output report log
	@if [ ! -f "$(CONFIG_FILE)" ]; then \
		$(TCLSH) scripts/tools/generate_default_config.tcl $(CONFIG_FILE); \
		echo -e "$(GREEN)[SUCCESS]$(NC) Created default config: $(CONFIG_FILE)"; \
	fi
	@# Create example RTL if not exists
	@if [ ! -f "rtl/src/example.v" ]; then \
		echo "module example(input clk, input rst_n, input [7:0] data_in, output reg [7:0] data_out);" > rtl/src/example.v; \
		echo "  always @(posedge clk or negedge rst_n) begin" >> rtl/src/example.v; \
		echo "    if (!rst_n) data_out <= 8'b0;" >> rtl/src/example.v; \
		echo "    else data_out <= data_in;" >> rtl/src/example.v; \
		echo "  end" >> rtl/src/example.v; \
		echo "endmodule" >> rtl/src/example.v; \
	fi
	@echo -e "$(GREEN)[SUCCESS]$(NC) Project initialized"

.PHONY: clean
clean:
	@echo -e "$(BLUE)[INFO]$(NC) Cleaning generated files..."
	@rm -rf $(WORK_DIR)/*.log $(WORK_DIR)/*.svf $(WORK_DIR)/*.mr
	@rm -rf $(LOG_DIR)/*.log
	@find . -name "*.pvl" -o -name "*.syn" -o -name "default.svf" | xargs rm -f
	@echo -e "$(GREEN)[SUCCESS]$(NC) Clean completed"

.PHONY: distclean
distclean: clean
	@echo -e "$(BLUE)[INFO]$(NC) Deep cleaning..."
	@rm -rf $(WORK_DIR) output/* report/* $(LOG_DIR)/*
	@echo -e "$(GREEN)[SUCCESS]$(NC) Deep clean completed"

.PHONY: archive
archive:
	@echo -e "$(BLUE)[INFO]$(NC) Creating archive..."
	@tar czf synthesis_$(TOP_MODULE)_$(TIMESTAMP).tar.gz \
		$(CONFIG_FILE) \
		$(OUTPUT_DIR) \
		$(REPORT_DIR) \
		$(LOG_DIR)/*$(TIMESTAMP)*
	@echo -e "$(GREEN)[SUCCESS]$(NC) Archive created: synthesis_$(TOP_MODULE)_$(TIMESTAMP).tar.gz"

.PHONY: help
help:
	@echo -e "$(CYAN)Industrial-Grade DC Synthesis System$(NC)"
	@echo ""
	@echo "Main Commands:"
	@echo "  make              - Run complete synthesis flow"
	@echo "  make synthesize   - Run synthesis only"
	@echo "  make analyze      - Analyze QoR results"
	@echo "  make report       - Generate detailed reports"
	@echo "  make monitor      - Monitor synthesis progress"
	@echo "  make compare      - Compare multiple runs"
	@echo ""
	@echo "Setup & Validation:"
	@echo "  make init         - Initialize project structure"
	@echo "  make validate     - Validate configuration"
	@echo "  make check        - Check prerequisites"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean        - Clean temporary files"
	@echo "  make distclean    - Remove all generated files"
	@echo "  make archive      - Create archive of results"
	@echo ""
	@echo "Configuration:"
	@echo "  CONFIG_FILE=<path> - Specify config file (default: config/project_config.yaml)"
	@echo "  DC_SHELL=<cmd>     - Specify DC command (default: dc_shell-t)"
	@echo ""

.PHONY: error_analysis
error_analysis:
	@echo -e "$(RED)╔════════════════════════════════════════╗$(NC)"
	@echo -e "$(RED)║         ERROR ANALYSIS                ║$(NC)"
	@echo -e "$(RED)╚════════════════════════════════════════╝$(NC)"
	@echo -e "$(YELLOW)[CHECKING]$(NC) Common synthesis issues..."
	@if [ -f "$(LOG_DIR)/synthesis_$(TIMESTAMP).log" ]; then \
		echo -e "\n$(YELLOW)Last 10 Errors/Warnings:$(NC)"; \
		grep -i "error\|warning\|violation" $(LOG_DIR)/synthesis_$(TIMESTAMP).log | tail -10; \
		echo -e "\n$(YELLOW)Unresolved References:$(NC)"; \
		grep -i "unresolved" $(LOG_DIR)/synthesis_$(TIMESTAMP).log | tail -5; \
	fi
	@echo -e "\n$(YELLOW)[HINT]$(NC) Check full log: $(LOG_DIR)/synthesis_$(TIMESTAMP).log"

.DEFAULT_GOAL := help