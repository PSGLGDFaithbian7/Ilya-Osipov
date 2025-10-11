# ============================================================================
# Industrial IC Automation Makefile for VCS+Verdi
# Supports both UVM and Non-UVM testbenches
# ============================================================================

# Project Configuration
PROJECT_NAME    ?= arithmetic_unit
TOP_MODULE     ?= tb_top
TESTCASE       ?= basic_test

# Tool Paths
VCS_HOME       ?= /path/to/vcs
VERDI_HOME     ?= /path/to/verdi
UVM_HOME       ?= $(VCS_HOME)/etc/uvm-1.2

# Directory Structure
SRC_DIR        := src
TB_DIR         := testbench
UVM_DIR        := uvm
SCRIPT_DIR     := scripts
CONFIG_DIR     := config
WORK_DIR       := work

# Get absolute path for reliable compilation
ROOT_DIR       := $(shell pwd)

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

# VCS Compilation Flags
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

# UVM or Non-UVM Configuration
ifdef UVM_ENABLE
    VCS_COMPILE_OPTS += -ntb_opts uvm-1.2 \
                        +define+UVM_NO_DEPRECATED \
                        +define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR
    ALL_FILES_ABS := $(UVM_FILES_ABS) $(TB_FILES_ABS) $(SRC_FILES_ABS)
    
    # UVM Simulation options
    SIM_OPTS := +UVM_TESTNAME=$(TESTCASE) \
                +UVM_VERBOSITY=UVM_MEDIUM
    
    # Add TCL script if exists
    ifneq (,$(wildcard $(SCRIPT_DIR)/simulate.tcl))
        SIM_OPTS += -ucli -do $(ROOT_DIR)/$(SCRIPT_DIR)/simulate.tcl
    endif
else
    ALL_FILES_ABS := $(TB_FILES_ABS) $(SRC_FILES_ABS)
    
    # Non-UVM Simulation options
    SIM_OPTS := +NUM_CASES=1000 \
                +SEED=$$RANDOM \
                +TIMEOUT_CYCLES=50000
endif

# Verdi Options
VERDI_OPTS     := -sv \
                  -ssf $(WORK_DIR)/$(PROJECT_NAME).fsdb \
                  -nologo

# Default Target
.PHONY: all clean compile sim debug wave help list_files

all: compile sim

# ============================================================================
# Compilation Phase
# ============================================================================
compile: $(WORK_DIR)/simv
	@echo "=== Compilation completed successfully ==="

$(WORK_DIR)/simv: $(SRC_FILES) $(TB_FILES) | $(WORK_DIR)
	@echo "=== Starting VCS compilation ==="
	@echo "Mode: $(if $(UVM_ENABLE),UVM,Non-UVM)"
	@echo "Top module: $(TOP_MODULE)"
	@echo "Source files: $(words $(SRC_FILES)) file(s)"
	@echo "Testbench files: $(words $(TB_FILES)) file(s)"
	cd $(WORK_DIR) && vcs $(VCS_COMPILE_OPTS) \
		-top $(TOP_MODULE) \
		-o simv \
		$(ALL_FILES_ABS) \
		-l compile.log
	@echo "✓ Compilation log: $(WORK_DIR)/compile.log"

# Create work directory
$(WORK_DIR):
	@mkdir -p $(WORK_DIR)

# ============================================================================
# Simulation Phase
# ============================================================================
sim: $(WORK_DIR)/simv
	@echo "=== Starting simulation ==="
	@echo "Options: $(SIM_OPTS)"
	cd $(WORK_DIR) && ./simv $(SIM_OPTS) -l sim.log
	@echo "✓ Simulation log: $(WORK_DIR)/sim.log"
	@if [ -f $(SCRIPT_DIR)/report.tcl ]; then \
		echo "=== Generating report ==="; \
		tclsh $(SCRIPT_DIR)/report.tcl; \
	fi

# Run with custom plusargs
sim_custom: $(WORK_DIR)/simv
	@echo "=== Running simulation with custom options ==="
	cd $(WORK_DIR) && ./simv $(SIM_OPTS) $(PLUSARGS) -l sim.log

# Interactive simulation
sim_interactive: $(WORK_DIR)/simv
	@echo "=== Starting interactive simulation ==="
	cd $(WORK_DIR) && ./simv -gui $(SIM_OPTS)

# Quick run with waves
sim_waves: $(WORK_DIR)/simv
	@echo "=== Running with waveform dump ==="
	cd $(WORK_DIR) && ./simv $(SIM_OPTS) +DUMP_WAVES -l sim.log

# ============================================================================
# Debug and Waveform Analysis
# ============================================================================
debug: compile
	@echo "=== Launching Verdi for debug ==="
	cd $(WORK_DIR) && verdi $(VERDI_OPTS) \
		-dbdir simv.daidir \
		$(ALL_FILES_ABS) &

wave: 
	@if [ -f $(WORK_DIR)/$(PROJECT_NAME).fsdb ]; then \
		echo "=== Opening waveform in Verdi ==="; \
		cd $(WORK_DIR) && verdi -ssf $(PROJECT_NAME).fsdb -nologo &; \
	elif [ -f $(WORK_DIR)/*.fsdb ]; then \
		echo "=== Opening waveform in Verdi ==="; \
		cd $(WORK_DIR) && verdi -ssf *.fsdb -nologo &; \
	else \
		echo "Error: No waveform file found. Run simulation with +DUMP_WAVES"; \
		exit 1; \
	fi

# ============================================================================
# UVM Specific Targets
# ============================================================================
uvm_compile:
	@echo "=== Compiling with UVM support ==="
	$(MAKE) compile UVM_ENABLE=1

uvm_sim:
	@echo "=== Running UVM simulation ==="
	$(MAKE) sim UVM_ENABLE=1 TESTCASE=$(TESTCASE)

uvm_regress:
	@echo "=== Running UVM regression ==="
	@for test in basic_test random_test constraint_test; do \
		echo ">>> Running test: $$test"; \
		$(MAKE) uvm_sim TESTCASE=$$test || exit 1; \
		echo ""; \
	done
	@echo "=== Regression completed ==="

# ============================================================================
# Non-UVM Specific Targets
# ============================================================================
non_uvm_compile:
	@echo "=== Compiling non-UVM testbench ==="
	$(MAKE) compile

non_uvm_sim:
	@echo "=== Running non-UVM simulation ==="
	$(MAKE) sim

non_uvm_regress:
	@echo "=== Running non-UVM regression ==="
	@for cases in 100 500 1000; do \
		echo ">>> Running with $$cases test cases"; \
		$(MAKE) sim PLUSARGS="+NUM_CASES=$$cases" || exit 1; \
		echo ""; \
	done
	@echo "=== Regression completed ==="

# Quick test
quick: clean compile sim

# ============================================================================
# Utility Targets
# ============================================================================
clean:
	@echo "=== Cleaning workspace ==="
	rm -rf $(WORK_DIR)/*
	rm -f *.log *.vpd *.fsdb *.vcd *.key
	find . -name "*.daidir" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "csrc" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "simv*" ! -name "*.sv" -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.log" -type f -delete 2>/dev/null || true
	@echo "✓ Workspace cleaned"

clean_all: clean
	rm -rf $(WORK_DIR)
	@echo "✓ Deep clean completed"

list_files:
	@echo "=== Discovered Files ==="
	@echo ""
	@echo "Source files ($(words $(SRC_FILES))):"
	@$(foreach file,$(SRC_FILES),echo "  - $(file)";)
	@echo ""
	@echo "Testbench files ($(words $(TB_FILES))):"
	@$(foreach file,$(TB_FILES),echo "  - $(file)";)
	@echo ""
	@if [ -n "$(UVM_FILES)" ]; then \
		echo "UVM files ($(words $(UVM_FILES))):"; \
		$(foreach file,$(UVM_FILES),echo "  - $(file)";) \
		echo ""; \
	fi
	@echo "Include directories:"
	@$(foreach dir,$(INC_DIRS),echo "  - $(dir)";)

check:
	@echo "=== Checking setup ==="
	@echo "Project: $(PROJECT_NAME)"
	@echo "Top module: $(TOP_MODULE)"
	@echo "Working directory: $(WORK_DIR)"
	@echo "Root directory: $(ROOT_DIR)"
	@echo ""
	@echo "Files found:"
	@echo "  Source: $(words $(SRC_FILES))"
	@echo "  Testbench: $(words $(TB_FILES))"
	@echo "  UVM: $(words $(UVM_FILES))"
	@echo ""
	@if [ $(words $(SRC_FILES)) -eq 0 ]; then \
		echo "⚠ Warning: No source files found in $(SRC_DIR)/"; \
	fi
	@if [ $(words $(TB_FILES)) -eq 0 ]; then \
		echo "⚠ Warning: No testbench files found in $(TB_DIR)/"; \
	fi

help:
	@echo "=== IC Automation Makefile Help ==="
	@echo ""
	@echo "Basic Targets:"
	@echo "  all              - Compile and simulate (default)"
	@echo "  compile          - Compile design only"
	@echo "  sim              - Run simulation"
	@echo "  sim_custom       - Run with custom PLUSARGS"
	@echo "  sim_waves        - Run with waveform dump"
	@echo "  sim_interactive  - Run GUI simulation"
	@echo "  quick            - Clean, compile and simulate"
	@echo ""
	@echo "Debug Targets:"
	@echo "  debug            - Launch Verdi debugger"
	@echo "  wave             - Open waveform viewer"
	@echo ""
	@echo "UVM Targets:"
	@echo "  uvm_compile      - Compile with UVM"
	@echo "  uvm_sim          - Run UVM simulation"
	@echo "  uvm_regress      - Run UVM regression"
	@echo ""
	@echo "Non-UVM Targets:"
	@echo "  non_uvm_compile  - Compile non-UVM testbench"
	@echo "  non_uvm_sim      - Run non-UVM simulation"
	@echo "  non_uvm_regress  - Run non-UVM regression"
	@echo ""
	@echo "Utility Targets:"
	@echo "  list_files       - List discovered files"
	@echo "  check            - Check setup"
	@echo "  clean            - Clean workspace"
	@echo "  clean_all        - Deep clean"
	@echo "  help             - Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  TOP_MODULE       - Top module name (current: $(TOP_MODULE))"
	@echo "  TESTCASE         - UVM test case (current: $(TESTCASE))"
	@echo "  PROJECT_NAME     - Project name (current: $(PROJECT_NAME))"
	@echo "  PLUSARGS         - Additional plusargs for sim_custom"
	@echo ""
	@echo "Examples:"
	@echo "  make compile"
	@echo "  make sim"
	@echo "  make sim_custom PLUSARGS=\"+NUM_CASES=500 +SEED=123\""
	@echo "  make uvm_sim TESTCASE=random_test"
	@echo "  make wave"