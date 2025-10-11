# ============================================================================
# Industrial IC Automation Makefile for VCS+Verdi - Enhanced Version
# Supports UVM, Non-UVM, Coverage, Performance Analysis
# Author: IC Verification Team
# Version: 2.0
# ============================================================================

# Project Configuration
PROJECT_NAME    ?= arithmetic_unit
TOP_MODULE     ?= tb_top
TESTCASE       ?= basic_test
SEED           ?= $(shell date +%s)

# Tool Paths - Auto-detect or use provided paths
VCS_HOME       ?= $(shell which vcs | xargs dirname | xargs dirname)
VERDI_HOME     ?= $(shell which verdi | xargs dirname | xargs dirname)
UVM_HOME       ?= $(VCS_HOME)/etc/uvm-1.2

# Directory Structure
SRC_DIR        := src
TB_DIR         := testbench
UVM_DIR        := uvm
SCRIPT_DIR     := scripts
CONFIG_DIR     := config
WORK_DIR       := work
REPORT_DIR     := reports
WAVE_DIR       := $(WORK_DIR)
COV_DIR        := $(WORK_DIR)/coverage

# Get absolute path for reliable compilation
ROOT_DIR       := $(shell pwd)

# Timestamp for runs
TIMESTAMP      := $(shell date +%Y%m%d_%H%M%S)

# File Discovery
HDL_EXTS       := .v .sv .vhdl .vhd
SRC_FILES      := $(foreach ext,$(HDL_EXTS),$(wildcard $(SRC_DIR)/*$(ext)))
TB_FILES       := $(foreach ext,$(HDL_EXTS),$(wildcard $(TB_DIR)/*$(ext)))
UVM_FILES      := $(foreach ext,$(HDL_EXTS),$(wildcard $(UVM_DIR)/*$(ext)))

# Convert to absolute paths for VCS
SRC_FILES_ABS  := $(addprefix $(ROOT_DIR)/,$(SRC_FILES))
TB_FILES_ABS   := $(addprefix $(ROOT_DIR)/,$(TB_FILES))
UVM_FILES_ABS  := $(addprefix $(ROOT_DIR)/,$(UVM_FILES))

# Include directories
INC_DIRS       := $(shell find . -name "*.vh" -o -name "*.svh" -o -name "*.h" 2>/dev/null | xargs dirname | sort -u)
INC_FLAGS      := $(addprefix +incdir+$(ROOT_DIR)/,$(INC_DIRS))

# ============================================================================
# Compilation Options
# ============================================================================

# Base VCS Compilation Flags
VCS_COMPILE_OPTS := -sverilog \
                    -full64 \
                    -debug_access+all \
                    -kdb \
                    +acc+rw \
                    -lca \
                    +v2k \
                    -CFLAGS -DVCS \
                    -j8 \
                    -timescale=1ns/1ps \
                    $(INC_FLAGS)

# Coverage Options (optional, enable with COV_ENABLE=1)
ifdef COV_ENABLE
    VCS_COMPILE_OPTS += -cm line+cond+fsm+tgl+branch+assert \
                        -cm_dir $(COV_DIR)/simv.vdb \
                        -cm_name $(TESTCASE)_$(TIMESTAMP)
    SIM_COVERAGE := -cm line+cond+fsm+tgl+branch+assert \
                    -cm_name $(TESTCASE)_$(TIMESTAMP)
else
    SIM_COVERAGE :=
endif

# Performance Profiling (enable with PROF_ENABLE=1)
ifdef PROF_ENABLE
    VCS_COMPILE_OPTS += -simprofile
    SIM_PROF := -simprofile time+mem
else
    SIM_PROF :=
endif

# UVM or Non-UVM Configuration
ifdef UVM_ENABLE
    VCS_COMPILE_OPTS += -ntb_opts uvm-1.2 \
                        +define+UVM_NO_DEPRECATED \
                        +define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR
    ALL_FILES_ABS := $(UVM_FILES_ABS) $(TB_FILES_ABS) $(SRC_FILES_ABS)
    
    # UVM Simulation options
    SIM_OPTS := +UVM_TESTNAME=$(TESTCASE) \
                +UVM_VERBOSITY=UVM_MEDIUM \
                +UVM_TIMEOUT=100000 \
                $(SIM_COVERAGE) \
                $(SIM_PROF)
    
    # Add TCL script if exists
    ifneq (,$(wildcard $(SCRIPT_DIR)/simulate.tcl))
        SIM_OPTS += -ucli -do $(ROOT_DIR)/$(SCRIPT_DIR)/simulate.tcl
    endif
else
    ALL_FILES_ABS := $(TB_FILES_ABS) $(SRC_FILES_ABS)
    
    # Non-UVM Simulation options
    SIM_OPTS := +NUM_CASES=1000 \
                +SEED=$(SEED) \
                +TIMEOUT_CYCLES=50000 \
                $(SIM_COVERAGE) \
                $(SIM_PROF)
endif

# Verdi Options
VERDI_OPTS     := -sv \
                  -ssf $(WAVE_DIR)/$(PROJECT_NAME).fsdb \
                  -nologo

# ============================================================================
# Color Output
# ============================================================================
NO_COLOR    := \033[0m
RED         := \033[0;31m
GREEN       := \033[0;32m
YELLOW      := \033[1;33m
BLUE        := \033[0;34m
MAGENTA     := \033[0;35m
CYAN        := \033[0;36m

# ============================================================================
# Default Target
# ============================================================================
.PHONY: all clean compile sim debug wave help list_files

.DEFAULT_GOAL := help

all: check compile sim

# ============================================================================
# Pre-flight Checks
# ============================================================================
.PHONY: check check_tools check_files

check: check_tools check_files
	@echo -e "$(GREEN)=== All checks passed ===$(NO_COLOR)"

check_tools:
	@echo -e "$(CYAN)=== Checking Tools ===$(NO_COLOR)"
	@which vcs > /dev/null 2>&1 || (echo -e "$(RED)ERROR: VCS not found$(NO_COLOR)" && exit 1)
	@echo -e "$(GREEN)✓ VCS found: $(shell which vcs)$(NO_COLOR)"
	@which verdi > /dev/null 2>&1 || echo -e "$(YELLOW)⚠ Verdi not found (optional)$(NO_COLOR)"
	@echo -e "$(GREEN)✓ Tools check complete$(NO_COLOR)"

check_files:
	@echo -e "$(CYAN)=== Checking Files ===$(NO_COLOR)"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Top module: $(TOP_MODULE)"
	@echo "Working directory: $(WORK_DIR)"
	@echo "Root directory: $(ROOT_DIR)"
	@echo ""
	@echo "Files found:"
	@echo "  Source: $(words $(SRC_FILES)) file(s)"
	@echo "  Testbench: $(words $(TB_FILES)) file(s)"
	@echo "  UVM: $(words $(UVM_FILES)) file(s)"
	@echo ""
	@if [ $(words $(SRC_FILES)) -eq 0 ]; then \
		echo -e "$(RED)✗ ERROR: No source files found in $(SRC_DIR)/$(NO_COLOR)"; \
		exit 1; \
	fi
	@if [ $(words $(TB_FILES)) -eq 0 ]; then \
		echo -e "$(RED)✗ ERROR: No testbench files found in $(TB_DIR)/$(NO_COLOR)"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)✓ Files check complete$(NO_COLOR)"

# ============================================================================
# Compilation Phase
# ============================================================================
.PHONY: compile compile_only

compile: $(WORK_DIR)/simv
	@echo -e "$(GREEN)=== Compilation completed successfully ===$(NO_COLOR)"

compile_only: check_tools | $(WORK_DIR) $(REPORT_DIR)
	@$(MAKE) $(WORK_DIR)/simv

$(WORK_DIR)/simv: $(SRC_FILES) $(TB_FILES) | $(WORK_DIR) $(REPORT_DIR)
	@echo -e "$(CYAN)=== Starting VCS compilation ===$(NO_COLOR)"
	@echo "Mode: $(if $(UVM_ENABLE),$(GREEN)UVM$(NO_COLOR),$(BLUE)Non-UVM$(NO_COLOR))"
	@echo "Coverage: $(if $(COV_ENABLE),$(GREEN)Enabled$(NO_COLOR),$(RED)Disabled$(NO_COLOR))"
	@echo "Profiling: $(if $(PROF_ENABLE),$(GREEN)Enabled$(NO_COLOR),$(RED)Disabled$(NO_COLOR))"
	@echo "Top module: $(TOP_MODULE)"
	@echo "Source files: $(words $(SRC_FILES)) file(s)"
	@echo "Testbench files: $(words $(TB_FILES)) file(s)"
	@echo "Timestamp: $(TIMESTAMP)"
	@echo ""
	@cd $(WORK_DIR) && vcs $(VCS_COMPILE_OPTS) \
		-top $(TOP_MODULE) \
		-o simv \
		$(ALL_FILES_ABS) \
		-l compile_$(TIMESTAMP).log 2>&1 | tee compile_current.log
	@if [ -f $(WORK_DIR)/simv ]; then \
		echo -e "$(GREEN)✓ Compilation successful$(NO_COLOR)"; \
		echo "✓ Compilation log: $(WORK_DIR)/compile_$(TIMESTAMP).log"; \
		ln -sf compile_$(TIMESTAMP).log $(WORK_DIR)/compile.log; \
	else \
		echo -e "$(RED)✗ Compilation failed$(NO_COLOR)"; \
		echo "See $(WORK_DIR)/compile_$(TIMESTAMP).log for details"; \
		exit 1; \
	fi

# Create directories
$(WORK_DIR) $(REPORT_DIR) $(COV_DIR):
	@mkdir -p $@

# ============================================================================
# Simulation Phase
# ============================================================================
.PHONY: sim sim_custom sim_interactive sim_waves sim_gui sim_batch

sim: $(WORK_DIR)/simv | $(REPORT_DIR)
	@echo -e "$(CYAN)=== Starting simulation ===$(NO_COLOR)"
	@echo "Test: $(TESTCASE)"
	@echo "Seed: $(SEED)"
	@echo "Options: $(SIM_OPTS)"
	@echo ""
	@cd $(WORK_DIR) && ./simv $(SIM_OPTS) -l sim_$(TIMESTAMP).log 2>&1 | tee sim_current.log
	@ln -sf sim_$(TIMESTAMP).log $(WORK_DIR)/sim.log
	@echo -e "$(GREEN)✓ Simulation log: $(WORK_DIR)/sim_$(TIMESTAMP).log$(NO_COLOR)"
	@$(MAKE) analyze_log
	@if [ -f $(SCRIPT_DIR)/report.tcl ]; then \
		echo -e "$(CYAN)=== Generating report ===$(NO_COLOR)"; \
		cd $(WORK_DIR) && tclsh ../$(SCRIPT_DIR)/report.tcl; \
	fi

# Run with custom plusargs
sim_custom: $(WORK_DIR)/simv
	@echo -e "$(CYAN)=== Running simulation with custom options ===$(NO_COLOR)"
	@echo "Custom args: $(PLUSARGS)"
	@cd $(WORK_DIR) && ./simv $(SIM_OPTS) $(PLUSARGS) -l sim_custom_$(TIMESTAMP).log
	@echo -e "$(GREEN)✓ Simulation log: $(WORK_DIR)/sim_custom_$(TIMESTAMP).log$(NO_COLOR)"

# Interactive simulation with GUI
sim_interactive: $(WORK_DIR)/simv
	@echo -e "$(CYAN)=== Starting interactive simulation ===$(NO_COLOR)"
	@cd $(WORK_DIR) && ./simv -gui $(SIM_OPTS)

sim_gui: sim_interactive

# Quick run with waves
sim_waves: $(WORK_DIR)/simv
	@echo -e "$(CYAN)=== Running with waveform dump ===$(NO_COLOR)"
	@cd $(WORK_DIR) && ./simv $(SIM_OPTS) +DUMP_WAVES +DUMP_FSDB -l sim_waves_$(TIMESTAMP).log
	@echo -e "$(GREEN)✓ Waveforms saved$(NO_COLOR)"
	@$(MAKE) list_waves

# Batch mode (non-interactive)
sim_batch: $(WORK_DIR)/simv
	@cd $(WORK_DIR) && ./simv $(SIM_OPTS) -l sim_batch_$(TIMESTAMP).log > /dev/null 2>&1
	@echo -e "$(GREEN)✓ Batch simulation complete$(NO_COLOR)"

# ============================================================================
# Log Analysis
# ============================================================================
.PHONY: analyze_log show_errors show_warnings

analyze_log:
	@echo -e "$(CYAN)=== Analyzing simulation log ===$(NO_COLOR)"
	@if [ -f $(WORK_DIR)/sim.log ]; then \
		ERRORS=$$(grep -i "error\|失败" $(WORK_DIR)/sim.log | grep -v "0 error" | wc -l); \
		WARNINGS=$$(grep -i "warning\|警告" $(WORK_DIR)/sim.log | wc -l); \
		PASSED=$$(grep -i "pass\|通过" $(WORK_DIR)/sim.log | tail -1); \
		echo "Errors: $$ERRORS"; \
		echo "Warnings: $$WARNINGS"; \
		echo "$$PASSED"; \
		if [ $$ERRORS -gt 0 ]; then \
			echo -e "$(RED)✗ Simulation has errors$(NO_COLOR)"; \
		else \
			echo -e "$(GREEN)✓ No errors found$(NO_COLOR)"; \
		fi; \
	fi

show_errors:
	@echo -e "$(RED)=== Errors ===$(NO_COLOR)"
	@grep -i "error\|失败" $(WORK_DIR)/sim.log | grep -v "0 error" || echo "No errors found"

show_warnings:
	@echo -e "$(YELLOW)=== Warnings ===$(NO_COLOR)"
	@grep -i "warning\|警告" $(WORK_DIR)/sim.log || echo "No warnings found"

# ============================================================================
# Coverage Analysis
# ============================================================================
.PHONY: cov_compile cov_sim cov_merge cov_report

cov_compile:
	@echo -e "$(CYAN)=== Compiling with coverage ===$(NO_COLOR)"
	@$(MAKE) compile COV_ENABLE=1

cov_sim:
	@echo -e "$(CYAN)=== Running with coverage ===$(NO_COLOR)"
	@$(MAKE) sim COV_ENABLE=1

cov_merge: | $(COV_DIR)
	@echo -e "$(CYAN)=== Merging coverage databases ===$(NO_COLOR)"
	@cd $(COV_DIR) && urg -dir simv.vdb -format text -report merged_coverage
	@echo -e "$(GREEN)✓ Coverage merged$(NO_COLOR)"

cov_report:
	@echo -e "$(CYAN)=== Generating coverage report ===$(NO_COLOR)"
	@if [ -d $(COV_DIR)/simv.vdb ]; then \
		cd $(COV_DIR) && urg -dir simv.vdb -format both -report coverage_report; \
		echo -e "$(GREEN)✓ Coverage report: $(COV_DIR)/coverage_report$(NO_COLOR)"; \
	else \
		echo -e "$(RED)No coverage database found. Run 'make cov_sim' first$(NO_COLOR)"; \
	fi

cov_gui:
	@echo -e "$(CYAN)=== Opening coverage GUI ===$(NO_COLOR)"
	@verdi -cov -covdir $(COV_DIR)/simv.vdb &

# ============================================================================
# Waveform Management
# ============================================================================
.PHONY: wave wave_fsdb wave_vcd list_waves latest_wave wave_clean wave_archive

wave:
	@echo -e "$(CYAN)=== Searching for waveform files ===$(NO_COLOR)"
	@if [ -f $(WAVE_DIR)/$(PROJECT_NAME).fsdb ]; then \
		echo "Opening: $(WAVE_DIR)/$(PROJECT_NAME).fsdb"; \
		cd $(WAVE_DIR) && verdi -ssf $(PROJECT_NAME).fsdb -nologo &; \
	elif [ -n "$$(ls $(WAVE_DIR)/*.fsdb 2>/dev/null)" ]; then \
		FSDB=$$(ls -t $(WAVE_DIR)/*.fsdb | head -1); \
		echo "Opening latest FSDB: $$FSDB"; \
		verdi -ssf $$FSDB -nologo &; \
	elif [ -n "$$(ls $(WAVE_DIR)/*.vcd 2>/dev/null)" ]; then \
		VCD=$$(ls -t $(WAVE_DIR)/*.vcd | head -1); \
		echo "Opening latest VCD: $$VCD"; \
		if command -v gtkwave > /dev/null; then \
			gtkwave $$VCD &; \
		else \
			echo -e "$(YELLOW)GTKWave not found, please install it$(NO_COLOR)"; \
		fi; \
	else \
		echo -e "$(RED)Error: No waveform files found in $(WAVE_DIR)/$(NO_COLOR)"; \
		echo "Run: make sim_waves"; \
		exit 1; \
	fi

wave_fsdb:
	@FSDB=$$(ls -t $(WAVE_DIR)/*.fsdb 2>/dev/null | head -1); \
	if [ -n "$$FSDB" ]; then \
		echo -e "$(GREEN)Opening FSDB: $$FSDB$(NO_COLOR)"; \
		verdi -ssf $$FSDB -nologo &; \
	else \
		echo -e "$(RED)No FSDB files found$(NO_COLOR)"; \
	fi

wave_vcd:
	@VCD=$$(ls -t $(WAVE_DIR)/*.vcd 2>/dev/null | head -1); \
	if [ -n "$$VCD" ]; then \
		echo -e "$(GREEN)Opening VCD: $$VCD$(NO_COLOR)"; \
		gtkwave $$VCD &; \
	else \
		echo -e "$(RED)No VCD files found$(NO_COLOR)"; \
	fi

list_waves:
	@echo -e "$(CYAN)=== Waveform Files ===$(NO_COLOR)"
	@find $(WAVE_DIR) -name "*.fsdb" -o -name "*.vcd" -o -name "*.vpd" 2>/dev/null | while read file; do \
		size=$$(du -h "$$file" | cut -f1); \
		mtime=$$(stat -c %y "$$file" 2>/dev/null | cut -d'.' -f1 || stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$$file"); \
		echo "  $$file ($$size) - $$mtime"; \
	done || echo "  No waveform files found"

latest_wave:
	@echo -e "$(CYAN)=== Latest Waveform ===$(NO_COLOR)"
	@ls -lt $(WAVE_DIR)/*.fsdb $(WAVE_DIR)/*.vcd 2>/dev/null | head -1 || echo "No waveform files"

wave_clean:
	@echo -e "$(YELLOW)=== Cleaning waveform files ===$(NO_COLOR)"
	@rm -f $(WAVE_DIR)/*.fsdb $(WAVE_DIR)/*.vcd $(WAVE_DIR)/*.vpd
	@echo -e "$(GREEN)✓ Waveform files cleaned$(NO_COLOR)"

wave_archive:
	@echo -e "$(CYAN)=== Archiving waveform files ===$(NO_COLOR)"
	@mkdir -p waves_archive
	@if ls $(WAVE_DIR)/*.fsdb $(WAVE_DIR)/*.vcd 2>/dev/null | grep -q .; then \
		tar -czf waves_archive/waves_$(TIMESTAMP).tar.gz $(WAVE_DIR)/*.fsdb $(WAVE_DIR)/*.vcd 2>/dev/null; \
		echo -e "$(GREEN)✓ Archived to: waves_archive/waves_$(TIMESTAMP).tar.gz$(NO_COLOR)"; \
	else \
		echo -e "$(YELLOW)No waveform files to archive$(NO_COLOR)"; \
	fi

# ============================================================================
# Debug and Analysis
# ============================================================================
.PHONY: debug debug_interactive

debug: compile
	@echo -e "$(CYAN)=== Launching Verdi for debug ===$(NO_COLOR)"
	@cd $(WORK_DIR) && verdi $(VERDI_OPTS) \
		-dbdir simv.daidir \
		$(ALL_FILES_ABS) &

debug_interactive:
	@echo -e "$(CYAN)=== Interactive Debug Mode ===$(NO_COLOR)"
	@cd $(WORK_DIR) && verdi -ssf *.fsdb -dbdir simv.daidir &

# ============================================================================
# UVM Specific Targets
# ============================================================================
.PHONY: uvm_compile uvm_sim uvm_regress uvm_random uvm_all

uvm_compile:
	@echo -e "$(CYAN)=== Compiling with UVM support ===$(NO_COLOR)"
	@$(MAKE) compile UVM_ENABLE=1

uvm_sim:
	@echo -e "$(CYAN)=== Running UVM simulation ===$(NO_COLOR)"
	@$(MAKE) sim UVM_ENABLE=1 TESTCASE=$(TESTCASE)

uvm_regress:
	@echo -e "$(CYAN)=== Running UVM regression ===$(NO_COLOR)"
	@$(MAKE) compile UVM_ENABLE=1
	@mkdir -p $(REPORT_DIR)/regression_$(TIMESTAMP)
	@for test in basic_test random_test constraint_test; do \
		echo -e "$(YELLOW)>>> Running test: $$test$(NO_COLOR)"; \
		$(MAKE) sim UVM_ENABLE=1 TESTCASE=$$test || exit 1; \
		cp $(WORK_DIR)/sim.log $(REPORT_DIR)/regression_$(TIMESTAMP)/$$test.log; \
		echo ""; \
	done
	@echo -e "$(GREEN)=== Regression completed ===$(NO_COLOR)"
	@echo "Reports saved to: $(REPORT_DIR)/regression_$(TIMESTAMP)/"

uvm_random:
	@$(MAKE) uvm_sim TESTCASE=random_test SEED=$(SEED)

uvm_all:
	@$(MAKE) uvm_compile
	@$(MAKE) uvm_regress

# ============================================================================
# Non-UVM Specific Targets
# ============================================================================
.PHONY: non_uvm_compile non_uvm_sim non_uvm_regress

non_uvm_compile:
	@echo -e "$(CYAN)=== Compiling non-UVM testbench ===$(NO_COLOR)"
	@$(MAKE) compile

non_uvm_sim:
	@echo -e "$(CYAN)=== Running non-UVM simulation ===$(NO_COLOR)"
	@$(MAKE) sim

non_uvm_regress:
	@echo -e "$(CYAN)=== Running non-UVM regression ===$(NO_COLOR)"
	@$(MAKE) compile
	@mkdir -p $(REPORT_DIR)/regression_$(TIMESTAMP)
	@for cases in 100 500 1000; do \
		echo -e "$(YELLOW)>>> Running with $$cases test cases$(NO_COLOR)"; \
		$(MAKE) sim PLUSARGS="+NUM_CASES=$$cases" || exit 1; \
		cp $(WORK_DIR)/sim.log $(REPORT_DIR)/regression_$(TIMESTAMP)/cases_$$cases.log; \
		echo ""; \
	done
	@echo -e "$(GREEN)=== Regression completed ===$(NO_COLOR)"
	@echo "Reports saved to: $(REPORT_DIR)/regression_$(TIMESTAMP)/"

# ============================================================================
# Quick Test Shortcuts
# ============================================================================
.PHONY: quick quick_uvm quick_waves smoke

quick: clean compile sim
	@echo -e "$(GREEN)=== Quick test complete ===$(NO_COLOR)"

quick_uvm: clean
	@$(MAKE) uvm_compile
	@$(MAKE) uvm_sim TESTCASE=basic_test
	@echo -e "$(GREEN)=== Quick UVM test complete ===$(NO_COLOR)"

quick_waves: clean compile sim_waves wave
	@echo -e "$(GREEN)=== Quick test with waves complete ===$(NO_COLOR)"

smoke:
	@echo -e "$(CYAN)=== Running smoke test ===$(NO_COLOR)"
	@$(MAKE) compile
	@$(MAKE) sim PLUSARGS="+NUM_CASES=10"
	@echo -e "$(GREEN)=== Smoke test complete ===$(NO_COLOR)"

# ============================================================================
# Utility Targets
# ============================================================================
.PHONY: clean clean_all clean_sim clean_waves list_files tree status

clean:
	@echo -e "$(YELLOW)=== Cleaning workspace ===$(NO_COLOR)"
	@rm -rf $(WORK_DIR)/*
	@rm -f *.log *.vpd *.key *.vcd
	@find . -name "*.daidir" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "csrc" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "simv*" ! -name "*.sv" -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.log" -type f -delete 2>/dev/null || true
	@find . -name "ucli.key" -delete 2>/dev/null || true
	@echo -e "$(GREEN)✓ Workspace cleaned$(NO_COLOR)"

clean_all: clean
	@echo -e "$(YELLOW)=== Deep cleaning ===$(NO_COLOR)"
	@rm -rf $(WORK_DIR) $(REPORT_DIR) waves_archive
	@echo -e "$(GREEN)✓ Deep clean completed$(NO_COLOR)"

clean_sim:
	@rm -f $(WORK_DIR)/*.log $(WORK_DIR)/simv
	@echo -e "$(GREEN)✓ Simulation files cleaned$(NO_COLOR)"

clean_waves:
	@$(MAKE) wave_clean

list_files:
	@echo -e "$(CYAN)=== Discovered Files ===$(NO_COLOR)"
	@echo ""
	@echo "Source files ($(words $(SRC_FILES))):"
	@$(foreach file,$(SRC_FILES),echo "  $(GREEN)✓$(NO_COLOR) $(file)";)
	@echo ""
	@echo "Testbench files ($(words $(TB_FILES))):"
	@$(foreach file,$(TB_FILES),echo "  $(GREEN)✓$(NO_COLOR) $(file)";)
	@echo ""
	@if [ -n "$(UVM_FILES)" ]; then \
		echo "UVM files ($(words $(UVM_FILES))):"; \
		$(foreach file,$(UVM_FILES),echo "  $(GREEN)✓$(NO_COLOR) $(file)";) \
		echo ""; \
	fi
	@echo "Include directories:"
	@$(foreach dir,$(INC_DIRS),echo "  $(CYAN)↳$(NO_COLOR) $(dir)";)

tree:
	@echo -e "$(CYAN)=== Directory Structure ===$(NO_COLOR)"
	@tree -L 2 -I 'work|*.log|*.fsdb|*.vcd' || ls -R

status:
	@echo -e "$(CYAN)=== Project Status ===$(NO_COLOR)"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Top Module: $(TOP_MODULE)"
	@echo "Mode: $(if $(UVM_ENABLE),UVM,Non-UVM)"
	@echo ""
	@echo "Files:"
	@echo "  Source: $(words $(SRC_FILES))"
	@echo "  Testbench: $(words $(TB_FILES))"
	@echo "  UVM: $(words $(UVM_FILES))"
	@echo ""
	@if [ -f $(WORK_DIR)/simv ]; then \
		echo -e "Compiled: $(GREEN)Yes$(NO_COLOR)"; \
		stat -c "Last compiled: %y" $(WORK_DIR)/simv 2>/dev/null || stat -f "Last compiled: %Sm" $(WORK_DIR)/simv; \
	else \
		echo -e "Compiled: $(RED)No$(NO_COLOR)"; \
	fi
	@echo ""
	@WAVES=$$(find $(WORK_DIR) -name "*.fsdb" -o -name "*.vcd" 2>/dev/null | wc -l); \
	echo "Waveforms: $$WAVES file(s)"
	@LOGS=$$(find $(WORK_DIR) -name "*.log" 2>/dev/null | wc -l); \
	echo "Logs: $$LOGS file(s)"

# ============================================================================
# Help
# ============================================================================
.PHONY: help help_all

help:
	@echo -e "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(NO_COLOR)"
	@echo -e "$(CYAN)║    IC Automation Makefile - Enhanced Version 2.0              ║$(NO_COLOR)"
	@echo -e "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(NO_COLOR)"
	@echo ""
	@echo -e "$(YELLOW)Basic Targets:$(NO_COLOR)"
	@echo "  all              - Run checks, compile and simulate"
	@echo "  compile          - Compile design only"
	@echo "  sim              - Run simulation"
	@echo "  sim_custom       - Run with custom PLUSARGS"
	@echo "  sim_waves        - Run with waveform dump"
	@echo "  sim_interactive  - Run GUI simulation"
	@echo "  quick            - Quick test (clean+compile+sim)"
	@echo "  smoke            - Quick smoke test"
	@echo ""
	@echo -e "$(YELLOW)Waveform Targets:$(NO_COLOR)"
	@echo "  wave             - Open waveform viewer (auto-detect)"
	@echo "  wave_fsdb        - Open FSDB with Verdi"
	@echo "  wave_vcd         - Open VCD with GTKWave"
	@echo "  list_waves       - List all waveform files"
	@echo "  latest_wave      - Show latest waveform info"
	@echo "  wave_clean       - Remove all waveform files"
	@echo "  wave_archive     - Archive waveform files"
	@echo ""
	@echo -e "$(YELLOW)Coverage Targets:$(NO_COLOR)"
	@echo "  cov_compile      - Compile with coverage"
	@echo "  cov_sim          - Simulate with coverage"
	@echo "  cov_report       - Generate coverage report"
	@echo "  cov_gui          - Open coverage GUI"
	@echo ""
	@echo -e "$(YELLOW)Debug Targets:$(NO_COLOR)"
	@echo "  debug            - Launch Verdi debugger"
	@echo "  analyze_log      - Analyze simulation log"
	@echo "  show_errors      - Show errors from log"
	@echo "  show_warnings    - Show warnings from log"
	@echo ""
	@echo -e "$(YELLOW)UVM Targets:$(NO_COLOR)"
	@echo "  uvm_compile      - Compile with UVM"
	@echo "  uvm_sim          - Run UVM simulation"
	@echo "  uvm_regress      - Run UVM regression"
	@echo "  uvm_random       - Run UVM random test"
	@echo "  quick_uvm        - Quick UVM test"
	@echo ""
	@echo -e "$(YELLOW)Non-UVM Targets:$(NO_COLOR)"
	@echo "  non_uvm_compile  - Compile non-UVM testbench"
	@echo "  non_uvm_sim      - Run non-UVM simulation"
	@echo "  non_uvm_regress  - Run non-UVM regression"
	@echo ""
	@echo -e "$(YELLOW)Utility Targets:$(NO_COLOR)"
	@echo "  check            - Run pre-flight checks"
	@echo "  list_files       - List discovered files"
	@echo "  tree             - Show directory tree"
	@echo "  status           - Show project status"
	@echo "  clean            - Clean workspace"
	@echo "  clean_all        - Deep clean everything"
	@echo "  help             - Show this help"
	@echo "  help_all         - Show detailed help"
	@echo ""
	@echo -e "$(YELLOW)Variables:$(NO_COLOR)"
	@echo "  TOP_MODULE       - Top module name (current: $(TOP_MODULE))"
	@echo "  TESTCASE         - Test case name (current: $(TESTCASE))"
	@echo "  PROJECT_NAME     - Project name (current: $(PROJECT_NAME))"
	@echo "  SEED             - Random seed (current: $(SEED))"
	@echo "  PLUSARGS         - Additional plusargs"
	@echo "  UVM_ENABLE       - Enable UVM mode (set to 1)"
	@echo "  COV_ENABLE       - Enable coverage (set to 1)"
	@echo "  PROF_ENABLE      - Enable profiling (set to 1)"
	@echo ""
	@echo -e "$(YELLOW)Examples:$(NO_COLOR)"
	@echo "  make quick"
	@echo "  make sim_custom PLUSARGS=\"+NUM_CASES=500 +SEED=123\""
	@echo "  make uvm_sim TESTCASE=random_test"
	@echo "  make cov_sim COV_ENABLE=1"
	@echo "  make wave"
	@echo ""
	@echo -e "For more information, type: $(GREEN)make help_all$(NO_COLOR)"

help_all: help
	@echo ""
	@echo -e "$(CYAN)=== Detailed Information ===$(NO_COLOR)"
	@echo ""
	@echo -e "$(YELLOW)Regression Testing:$(NO_COLOR)"
	@echo "  UVM regression runs: basic_test, random_test, constraint_test"
	@echo "  Non-UVM regression runs: 100, 500, 1000 test cases"
	@echo "  Results saved to: $(REPORT_DIR)/regression_<timestamp>/"
	@echo ""
	@echo -e "$(YELLOW)Coverage Collection:$(NO_COLOR)"
	@echo "  Coverage types: line, condition, FSM, toggle, branch, assertion"
	@echo "  Database location: $(COV_DIR)/simv.vdb"
	@echo "  Reports: $(COV_DIR)/coverage_report/"
	@echo ""
	@echo -e "$(YELLOW)Waveform Files:$(NO_COLOR)"
	@echo "  Location: $(WAVE_DIR)/"
	@echo "  Formats: FSDB (Verdi), VCD (GTKWave)"
	@echo "  Archive: waves_archive/waves_<timestamp>.tar.gz"
	@echo ""
	@echo -e "$(YELLOW)Directory Structure:$(NO_COLOR)"
	@echo "  $(SRC_DIR)/       - RTL source files"
	@echo "  $(TB_DIR)/        - Testbench files"
	@echo "  $(UVM_DIR)/       - UVM files"
	@echo "  $(SCRIPT_DIR)/    - TCL scripts"
	@echo "  $(WORK_DIR)/      - Working directory"
	@echo "  $(REPORT_DIR)/    - Reports and logs"
	@echo ""