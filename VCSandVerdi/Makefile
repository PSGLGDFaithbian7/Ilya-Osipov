# ============================================================================
# Industrial IC Automation Makefile for VCS+Verdi with UVM Support
# Optimized for Arithmetic Units and AI Chip Development
# Fixed all VCS/Verdi compatibility issues
# ============================================================================

# Project Configuration
PROJECT_NAME    ?= arithmetic_unit
TOP_MODULE     ?= tb_top
TESTCASE       ?= basic_test

# Tool Paths - Adjust according to your installation
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

# File Discovery - Automatically find HDL files
HDL_EXTS       := .v .sv .vhdl .vhd
SRC_FILES      := $(foreach ext,$(HDL_EXTS),$(wildcard $(SRC_DIR)/*$(ext)))
TB_FILES       := $(foreach ext,$(HDL_EXTS),$(wildcard $(TB_DIR)/*$(ext)))
UVM_FILES      := $(foreach ext,$(HDL_EXTS),$(wildcard $(UVM_DIR)/*$(ext)))

# Header and Include File Discovery
INC_DIRS       := $(shell find . -name "*.vh" -o -name "*.svh" -o -name "*.h" | xargs dirname | sort -u)
INC_FLAGS      := $(addprefix +incdir+,$(INC_DIRS))

# Macro Discovery - Find define files
DEFINE_FILES   := $(shell find . -name "*_defines.v" -o -name "*_defines.sv" -o -name "*_pkg.sv")
DEFINE_FLAGS   := $(addprefix -f ,$(DEFINE_FILES))

# VCS Compilation Flags - Fixed for VCS compatibility
VCS_COMPILE_OPTS := -sverilog \
                    -full64 \
                    -debug_access+all \
                    -kdb \
                    +acc+rw \
                    -lca \
                    +v2k \
                    -CFLAGS -DVCS \
                    -j8 \
                    -no_auto_dsp \
                    $(INC_FLAGS) \
                    $(DEFINE_FLAGS)

# Note: Removed -timescale from here to avoid conflicts with source code timescale directives
# Add -timescale=1ns/1ps only if your source files don't have `timescale directives

# UVM Configuration
ifdef UVM_ENABLE
    VCS_COMPILE_OPTS += -ntb_opts uvm-1.2 \
                        +define+UVM_NO_DEPRECATED \
                        +define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR
    ALL_FILES := $(UVM_FILES) $(TB_FILES) $(SRC_FILES)
else
    ALL_FILES := $(TB_FILES) $(SRC_FILES)
endif

# Simulation Options - Fixed UCLI integration
SIM_OPTS       := +UVM_TESTNAME=$(TESTCASE) \
                  +UVM_VERBOSITY=UVM_MEDIUM \
                  -ucli \
                  -do $(SCRIPT_DIR)/simulate.tcl

# Verdi Options
VERDI_OPTS     := -sv \
                  -ssf $(WORK_DIR)/$(PROJECT_NAME).fsdb \
                  -nologo

# Default Target
.PHONY: all clean compile sim debug wave help

all: compile sim

# ============================================================================
# Compilation Phase
# ============================================================================
compile: $(WORK_DIR)/simv
	@echo "=== Compilation completed successfully ==="

$(WORK_DIR)/simv: $(ALL_FILES) | $(WORK_DIR)
	@echo "=== Starting VCS compilation ==="
	@echo "Source files found: $(words $(ALL_FILES)) files"
	@echo "Include directories: $(INC_DIRS)"
	cd $(WORK_DIR) && vcs $(VCS_COMPILE_OPTS) \
		-top $(TOP_MODULE) \
		-o simv \
		$(ALL_FILES) \
		-l compile.log

# Create work directory
$(WORK_DIR):
	@mkdir -p $(WORK_DIR)

# ============================================================================
# Simulation Phase with UCLI/TCL Interface
# ============================================================================
sim: $(WORK_DIR)/simv
	@echo "=== Starting simulation with UCLI interface ==="
	cd $(WORK_DIR) && ./simv $(SIM_OPTS) -l sim.log && \
	if [ -f ../$(SCRIPT_DIR)/report.tcl ]; then tclsh ../$(SCRIPT_DIR)/report.tcl; fi

# Interactive simulation with full UCLI control
sim_interactive: $(WORK_DIR)/simv
	@echo "=== Starting interactive simulation ==="
	cd $(WORK_DIR) && ./simv -gui $(SIM_OPTS)

# ============================================================================
# Debug and Waveform Analysis
# ============================================================================
debug: compile
	@echo "=== Launching Verdi for debug ==="
	cd $(WORK_DIR) && verdi $(VERDI_OPTS) \
		-dbdir simv.daidir \
		+signal+report+file+../$(SCRIPT_DIR)/signals.txt \
		$(ALL_FILES) &

wave: 
	@if [ -f $(WORK_DIR)/$(PROJECT_NAME).fsdb ]; then \
		echo "=== Opening waveform in Verdi ==="; \
		cd $(WORK_DIR) && verdi -ssf $(PROJECT_NAME).fsdb -nologo &; \
	else \
		echo "Error: No waveform file found. Run simulation first."; \
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
		echo "Running test: $$test"; \
		$(MAKE) uvm_sim TESTCASE=$$test; \
	done

# ============================================================================
# AI Chip Optimization Targets
# ============================================================================
ai_chip_sim:
	@echo "=== AI Chip optimized simulation ==="
	$(MAKE) compile VCS_COMPILE_OPTS="$(VCS_COMPILE_OPTS) +define+AI_CHIP_MODE +define+HIGH_PERFORMANCE"
	$(MAKE) sim SIM_OPTS="$(SIM_OPTS) +AI_VECTORS=1000000"

performance_analysis:
	@echo "=== Performance analysis for arithmetic units ==="
	cd $(WORK_DIR) && ./simv +PERF_ANALYSIS=1 +VECTOR_COUNT=1000000 -l perf.log

# ============================================================================
# Non-UVM Alternative
# ============================================================================
non_uvm_sim:
	@echo "=== Running directed tests without UVM ==="
	$(MAKE) compile 
	cd $(WORK_DIR) && ./simv +TESTCASE=$(TESTCASE) +DIRECTED_TEST=1

# Create simple testbench template
create_simple_tb:
	@echo "Creating simple testbench template..."
	@mkdir -p $(TB_DIR)
	@cat > $(TB_DIR)/simple_tb.sv << 'EOF'
`timescale 1ns/1ps

module tb_top;
    reg clk, rst_n;
    
    // Clock generation - 100MHz clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Reset sequence
    initial begin
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        $display("Reset released at time %0t", $time);
    end
    
    // Your DUT instantiation here
    // arithmetic_unit dut (
    //     .clk(clk), 
    //     .rst_n(rst_n)
    //     // Add your ports here
    // );
    
    // Test sequences
    initial begin
        $display("Starting directed test at time %0t", $time);
        wait(rst_n);
        repeat(10) @(posedge clk);
        
        // Add your test sequences here
        // Example:
        // dut.operand_a = 32'h12345678;
        // dut.operand_b = 32'h87654321;
        // dut.operation = 3'b001; // ADD
        // dut.valid_in = 1'b1;
        // @(posedge clk);
        // dut.valid_in = 1'b0;
        
        repeat(1000) @(posedge clk);
        $display("Test completed at time %0t", $time);
        $finish;
    end
    
    // FSDB waveform dumping - This is where FSDB calls belong
    initial begin
        $fsdbDumpfile("$(PROJECT_NAME).fsdb");
        $fsdbDumpvars(0, tb_top);
        $fsdbDumpMDA(0, tb_top); // For memory arrays
        $display("FSDB dumping enabled: $(PROJECT_NAME).fsdb");
    end

    // Performance monitoring (simple counters)
    integer cycle_count = 0;
    integer operation_count = 0;
    
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
            // if (dut.valid_out) operation_count <= operation_count + 1;
        end
    end
    
    // End-of-simulation report
    final begin
        $display("=== Simulation Statistics ===");
        $display("Total cycles: %0d", cycle_count);
        $display("Operations: %0d", operation_count);
        if (cycle_count > 0) begin
            $display("Efficiency: %.2f%%", (operation_count * 100.0) / cycle_count);
        end
    end
endmodule
EOF
	@echo "Simple testbench created at $(TB_DIR)/simple_tb.sv"

# ============================================================================
# Utility Targets
# ============================================================================
clean:
	@echo "=== Cleaning workspace ==="
	rm -rf $(WORK_DIR)/* 
	rm -f *.log *.vpd *.fsdb *.vcd
	find . -name "*.daidir" -exec rm -rf {} + 2>/dev/null || true
	find . -name "csrc" -exec rm -rf {} + 2>/dev/null || true
	find . -name "simv*" -exec rm -rf {} + 2>/dev/null || true

clean_all: clean
	rm -rf $(WORK_DIR)

list_files:
	@echo "=== Discovered Files ==="
	@echo "Source files ($(words $(SRC_FILES))):"
	@$(foreach file,$(SRC_FILES),echo "  $(file)";)
	@echo "Testbench files ($(words $(TB_FILES))):"
	@$(foreach file,$(TB_FILES),echo "  $(file)";)
	@echo "Include directories:"
	@$(foreach dir,$(INC_DIRS),echo "  $(dir)";)

help:
	@echo "=== IC Automation Makefile Help ==="
	@echo "Available targets:"
	@echo "  all              - Compile and simulate"
	@echo "  compile          - Compile design"
	@echo "  sim              - Run simulation"
	@echo "  sim_interactive  - Run GUI simulation"
	@echo "  debug            - Launch Verdi debugger"
	@echo "  wave             - Open waveform viewer"
	@echo "  uvm_compile      - Compile with UVM"
	@echo "  uvm_sim          - Run UVM simulation"
	@echo "  uvm_regress      - Run UVM regression"
	@echo "  non_uvm_sim      - Run without UVM"
	@echo "  create_simple_tb - Create simple testbench template"
	@echo "  ai_chip_sim      - AI chip optimized simulation"
	@echo "  performance_analysis - Performance analysis"
	@echo "  list_files       - List discovered files"
	@echo "  clean            - Clean workspace"
	@echo "  clean_all        - Deep clean"
	@echo ""
	@echo "Variables:"
	@echo "  TOP_MODULE       - Top module name ($(TOP_MODULE))"
	@echo "  TESTCASE         - UVM test case ($(TESTCASE))"
	@echo "  PROJECT_NAME     - Project name ($(PROJECT_NAME))"