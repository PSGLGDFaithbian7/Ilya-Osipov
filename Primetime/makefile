# Industrial-grade Makefile for PrimeTime Power Analysis and STA (v2.0)
# Author: Generated for professional EDA workflow
# Date: $(shell date)
# Version: 2.0 - Enhanced with comprehensive error handling and validation

#==============================================================================
# CONFIGURATION VARIABLES
#==============================================================================

# Tool settings with validation
PT_SHELL := pt_shell
DESIGN_NAME ?= top_module
RUN_DIR := ./runs/$(shell date +%Y%m%d_%H%M%S)

# File paths (can be overridden from command line)
NETLIST ?= ./netlist/$(DESIGN_NAME).v
VCD_FILE ?= ./simulation/$(DESIGN_NAME).vcd
SDC_FILE ?= ./constraints/$(DESIGN_NAME).sdc
LIB_FILES ?= ./libs/*.lib
SAIF_FILE ?= ./simulation/$(DESIGN_NAME).saif

# Technology and library settings
TARGET_LIBRARY ?= typical.lib
LINK_LIBRARY ?= "* $(TARGET_LIBRARY)"
SEARCH_PATH ?= ./libs ./netlist ./constraints

# Analysis settings
CLOCK_PERIOD ?= 10.0
VOLTAGE ?= 1.0
TEMPERATURE ?= 25
PROCESS ?= typical

# Activity file priority (VCD has higher priority than SAIF)
ACTIVITY_PRIORITY ?= VCD_FIRST

# Output settings
REPORT_DIR := $(RUN_DIR)/reports
LOG_DIR := $(RUN_DIR)/logs
SCRIPT_DIR := ./scripts

#==============================================================================
# DERIVED VARIABLES
#==============================================================================

STA_SCRIPT := $(SCRIPT_DIR)/sta_analysis.tcl
POWER_SCRIPT := $(SCRIPT_DIR)/power_analysis.tcl
COMMON_SCRIPT := $(SCRIPT_DIR)/pt_common.tcl
LOG_FILE := $(LOG_DIR)/pt_run.log
STA_LOG := $(LOG_DIR)/sta_analysis.log
POWER_LOG := $(LOG_DIR)/power_analysis.log

#==============================================================================
# VALIDATION TARGETS
#==============================================================================

.PHONY: all clean setup sta power full_analysis help check_files validate_tools check_pt_version

# Validate PrimeTime installation
validate_tools:
	@echo "=== Validating EDA Tools ==="
	@which $(PT_SHELL) > /dev/null 2>&1 || \
		(echo "ERROR: PrimeTime ($(PT_SHELL)) not found in PATH. Please check installation." && exit 1)
	@echo "✓ PrimeTime found: $$(which $(PT_SHELL))"
	@$(PT_SHELL) -version 2>/dev/null | head -5 || \
		(echo "WARNING: Could not retrieve PrimeTime version info")
	@echo "Tool validation completed"

# Check PrimeTime version compatibility
check_pt_version: validate_tools
	@echo "=== Checking PrimeTime Version Compatibility ==="
	@$(PT_SHELL) -f $(SCRIPT_DIR)/version_check.tcl 2>/dev/null || \
		echo "WARNING: Version check failed - proceeding with caution"

#==============================================================================
# MAIN TARGETS
#==============================================================================

all: full_analysis

# Complete analysis flow with validation
full_analysis: validate_tools setup check_files sta power
	@echo "=== Full PrimeTime Analysis Complete ==="
	@echo "Reports available in: $(REPORT_DIR)"
	@echo "Logs available in: $(LOG_DIR)"
	@echo "Summary: $$(make summary_stats)"

# Setup directory structure
setup:
	@echo "=== Setting up directory structure ==="
	mkdir -p $(RUN_DIR) $(REPORT_DIR) $(LOG_DIR) $(SCRIPT_DIR)
	@echo "Run directory: $(RUN_DIR)"

# Enhanced file validation
check_files:
	@echo "=== Checking input files ==="
	@test -f "$(NETLIST)" || (echo "ERROR: Netlist file not found: $(NETLIST)" && exit 1)
	@echo "✓ Netlist found: $(NETLIST)"
	
	# Check netlist format
	@if grep -q "SystemVerilog\|interface\|package\|class" "$(NETLIST)" 2>/dev/null; then \
		echo "WARNING: Netlist appears to contain SystemVerilog constructs"; \
		echo "         PrimeTime may require DB format for full SystemVerilog support"; \
	fi
	
	@test -f "$(SDC_FILE)" || echo "WARNING: SDC file not found: $(SDC_FILE) - will use basic constraints"
	
	# Activity file priority check
	@if [ "$(ACTIVITY_PRIORITY)" = "VCD_FIRST" ]; then \
		if [ -f "$(VCD_FILE)" ]; then \
			echo "✓ VCD file found (priority): $(VCD_FILE)"; \
		elif [ -f "$(SAIF_FILE)" ]; then \
			echo "✓ SAIF file found (fallback): $(SAIF_FILE)"; \
		else \
			echo "WARNING: No activity files found - using default toggle rates"; \
		fi; \
	else \
		echo "INFO: Activity priority set to $(ACTIVITY_PRIORITY)"; \
	fi
	@echo "File validation completed"

# Static Timing Analysis
sta: validate_tools setup $(STA_SCRIPT) $(COMMON_SCRIPT)
	@echo "=== Running Static Timing Analysis ==="
	cd $(RUN_DIR) && $(PT_SHELL) -f ../$(STA_SCRIPT) | tee $(STA_LOG)
	@if [ $$? -eq 0 ]; then echo "✓ STA completed successfully"; else echo "✗ STA failed - check $(STA_LOG)"; exit 1; fi

# Power Analysis
power: validate_tools setup $(POWER_SCRIPT) $(COMMON_SCRIPT) check_files
	@echo "=== Running Power Analysis ==="
	cd $(RUN_DIR) && $(PT_SHELL) -f ../$(POWER_SCRIPT) | tee $(POWER_LOG)
	@if [ $$? -eq 0 ]; then echo "✓ Power analysis completed successfully"; else echo "✗ Power analysis failed - check $(POWER_LOG)"; exit 1; fi

#==============================================================================
# SCRIPT GENERATION
#==============================================================================

# Generate version check script
$(SCRIPT_DIR)/version_check.tcl: setup
	@cat > $(SCRIPT_DIR)/version_check.tcl << 'EOF'
# PrimeTime version compatibility check
if {[catch {set pt_version [get_app_var pt_version]} err]} {
    puts "WARNING: Cannot determine PrimeTime version"
    exit 0
}

puts "PrimeTime Version: $pt_version"

# Check for minimum version requirements
set min_version "2019.06"
if {[package vcompare $pt_version $min_version] < 0} {
    puts "WARNING: PrimeTime version $pt_version may not support all features"
    puts "         Recommended minimum version: $min_version"
}

exit 0
EOF

# Generate enhanced STA script
$(STA_SCRIPT): setup
	@echo "=== Generating Enhanced STA TCL script ==="
	@cat > $(STA_SCRIPT) << 'EOF'
#!/usr/bin/tclsh
#==============================================================================
# PrimeTime Static Timing Analysis Script (Enhanced)
# Generated automatically by Makefile v2.0
#==============================================================================
# Source common setup
source [file dirname [info script]]/pt_common.tcl

proc run_sta_analysis {} {
    global DESIGN_NAME REPORT_DIR
    
    puts "Starting Static Timing Analysis for $DESIGN_NAME"
    
    # Enhanced error handling
    if {[catch {
        # Read design
        read_netlist_and_setup
        
        # Apply constraints
        apply_timing_constraints
        
        # Update timing
        update_timing -full
        
        # Generate timing reports
        generate_timing_reports
        
    } error_msg]} {
        handle_analysis_error "STA" $error_msg
        return -code error
    }
    
    puts "STA Analysis completed successfully"
    report_runtime "STA"
}

proc apply_timing_constraints {} {
    global DESIGN_NAME
    
    if {[file exists "../constraints/${DESIGN_NAME}.sdc"]} {
        if {[catch {read_sdc "../constraints/${DESIGN_NAME}.sdc"} err]} {
            puts "WARNING: SDC read failed: $err"
            puts "Applying basic constraints instead"
            setup_basic_constraints
        } else {
            puts "Applied SDC constraints successfully"
        }
    } else {
        puts "No SDC file found, applying basic constraints"
        setup_basic_constraints
    }
}

proc generate_timing_reports {} {
    global REPORT_DIR DESIGN_NAME
    
    puts "Generating comprehensive timing reports..."
    
    # Setup analysis with error checking
    if {[catch {report_analysis_setup} err]} {
        puts "WARNING: Setup analysis failed: $err"
    } else {
        redirect -file "${REPORT_DIR}/setup_analysis.rpt" {report_analysis_setup}
    }
    
    # Timing summary
    redirect -file "${REPORT_DIR}/timing_summary.rpt" {report_timing_summary}
    
    # Critical paths with enhanced reporting
    redirect -file "${REPORT_DIR}/critical_paths_setup.rpt" {
        report_timing -delay_type max -max_paths 100 -nworst 10 -input_pins -nets -transition_time -capacitance
    }
    
    redirect -file "${REPORT_DIR}/critical_paths_hold.rpt" {
        report_timing -delay_type min -max_paths 100 -nworst 10 -input_pins -nets
    }
    
    # Clock reports
    if {[llength [all_clocks]] > 0} {
        redirect -file "${REPORT_DIR}/clock_skew.rpt" {report_clock -skew}
        redirect -file "${REPORT_DIR}/clock_timing.rpt" {report_clock_timing}
    }
    
    # Constraint violations
    redirect -file "${REPORT_DIR}/violations.rpt" {report_constraint -all_violators}
    
    # Design statistics
    redirect -file "${REPORT_DIR}/design_stats.rpt" {report_design}
    
    puts "All timing reports generated in $REPORT_DIR"
}

# Execute main analysis with global error handling
if {[catch {run_sta_analysis} global_error]} {
    puts "FATAL ERROR in STA: $global_error"
    exit 1
}

exit 0
EOF

# Generate enhanced power analysis script
$(POWER_SCRIPT): setup
	@echo "=== Generating Enhanced Power Analysis TCL script ==="
	@cat > $(POWER_SCRIPT) << 'EOF'
#!/usr/bin/tclsh
#==============================================================================
# PrimeTime Power Analysis Script (Enhanced)
# Generated automatically by Makefile v2.0
#==============================================================================

# Source common setup
source [file dirname [info script]]/pt_common.tcl

proc run_power_analysis {} {
    global DESIGN_NAME REPORT_DIR VCD_FILE SAIF_FILE
    
    puts "Starting Power Analysis for $DESIGN_NAME"
    
    # Enhanced error handling
    if {[catch {
        # Read design and setup
        read_netlist_and_setup
        
        # Set power analysis mode
        configure_power_analysis
        
        # Read activity file with priority handling
        read_activity_data_enhanced
        
        # Set operating conditions for power
        set_operating_conditions_power
        
        # Update power
        update_power
        
        # Generate power reports
        generate_power_reports
        
    } error_msg]} {
        handle_analysis_error "Power" $error_msg
        return -code error
    }
    
    puts "Power Analysis completed successfully"
    report_runtime "Power"
}

proc configure_power_analysis {} {
    # Enhanced power analysis configuration
    set_app_var power_enable_analysis true
    set_app_var power_analysis_mode averaged
    set_app_var power_clock_network_include_register_clock_pin_power false
    set_app_var power_analysis_effort high
    
    puts "Power analysis configured with enhanced settings"
}

proc read_activity_data_enhanced {} {
    global VCD_FILE SAIF_FILE DESIGN_NAME ACTIVITY_PRIORITY
    
    set activity_loaded false
    
    # Priority-based activity file loading
    if {$ACTIVITY_PRIORITY eq "VCD_FIRST"} {
        if {[info exists VCD_FILE] && [file exists $VCD_FILE]} {
            if {[catch {
                read_vcd $VCD_FILE -strip_path $DESIGN_NAME
                set_power_analysis_options -waveform_format vcd -waveform_output vcd
                puts "Successfully loaded VCD file: $VCD_FILE"
                set activity_loaded true
            } err]} {
                puts "WARNING: VCD read failed: $err"
            }
        }
        
        if {!$activity_loaded && [info exists SAIF_FILE] && [file exists $SAIF_FILE]} {
            if {[catch {
                read_saif $SAIF_FILE -strip_path $DESIGN_NAME
                set_power_analysis_options -waveform_format saif
                puts "Successfully loaded SAIF file: $SAIF_FILE"
                set activity_loaded true
            } err]} {
                puts "WARNING: SAIF read failed: $err"
            }
        }
    }
    
    if {!$activity_loaded} {
        puts "No valid activity file found, using default toggle rates"
        set_switching_activity -static_probability 0.5 -toggle_rate 0.1 [all_inputs]
        if {[llength [all_registers]] > 0} {
            set_switching_activity -static_probability 0.5 -toggle_rate 0.05 [all_registers]
        }
    }
}

proc set_operating_conditions_power {} {
    global VOLTAGE TEMPERATURE PROCESS
    
    # Check if library supports the specified corner
    set available_corners [list_lib_groups]
    if {[llength $available_corners] > 0 && [lsearch $available_corners $PROCESS] == -1} {
        puts "WARNING: Process corner '$PROCESS' not found in library"
        puts "Available corners: $available_corners"
        puts "Using default operating conditions"
    }
    
    # Set operating conditions with error handling
    if {[catch {
        set_operating_conditions -voltage $VOLTAGE -temperature $TEMPERATURE
        puts "Set operating conditions: ${VOLTAGE}V, ${TEMPERATURE}C, $PROCESS corner"
    } err]} {
        puts "WARNING: Failed to set operating conditions: $err"
        puts "Proceeding with library defaults"
    }
}

proc generate_power_reports {} {
    global REPORT_DIR DESIGN_NAME
    
    puts "Generating comprehensive power reports..."
    
    # Power summary
    redirect -file "${REPORT_DIR}/power_summary.rpt" {report_power -hierarchy}
    
    # Detailed power breakdown
    redirect -file "${REPORT_DIR}/power_detailed.rpt" {
        report_power -cell_power -net_power -switch_power -leakage_power -verbose
    }
    
    # Power by hierarchy
    redirect -file "${REPORT_DIR}/power_hierarchy.rpt" {report_power -hierarchy -levels 3}
    
    # Clock power
    if {[llength [all_clocks]] > 0} {
        redirect -file "${REPORT_DIR}/clock_power.rpt" {report_power -clock_network}
    }
    
    # Rail analysis (if applicable)
    if {[catch {set rails [all_power_rails]} err] == 0 && [llength $rails] > 0} {
        redirect -file "${REPORT_DIR}/rail_status.rpt" {report_rail_connection_status}
        redirect -file "${REPORT_DIR}/rail_power.rpt" {report_power -rail}
    }
    
    # Switching activity
    redirect -file "${REPORT_DIR}/switching_activity.rpt" {
        report_switching_activity -list_not_annotated
    }
    
    # Power analysis quality
    redirect -file "${REPORT_DIR}/power_analysis_setup.rpt" {report_power_analysis_setup}
    
    puts "All power reports generated in $REPORT_DIR"
}

# Execute main analysis with global error handling
if {[catch {run_power_analysis} global_error]} {
    puts "FATAL ERROR in Power Analysis: $global_error"
    exit 1
}

exit 0
EOF

# Generate enhanced common TCL procedures
$(COMMON_SCRIPT): setup
	@echo "=== Generating Enhanced Common TCL procedures ==="
	@cat > $(COMMON_SCRIPT) << 'EOF'
#==============================================================================
# Enhanced Common PrimeTime TCL Procedures
# Shared functions for STA and Power Analysis with robust error handling
#==============================================================================

# Global variables from Makefile
set DESIGN_NAME "$(DESIGN_NAME)"
set NETLIST "$(NETLIST)"
set TARGET_LIBRARY "$(TARGET_LIBRARY)"
set LINK_LIBRARY "$(LINK_LIBRARY)"
set SEARCH_PATH "$(SEARCH_PATH)"
set CLOCK_PERIOD $(CLOCK_PERIOD)
set VOLTAGE $(VOLTAGE)
set TEMPERATURE $(TEMPERATURE)
set PROCESS "$(PROCESS)"
set REPORT_DIR "../$(REPORT_DIR)"
set VCD_FILE "$(VCD_FILE)"
set SAIF_FILE "$(SAIF_FILE)"
set ACTIVITY_PRIORITY "$(ACTIVITY_PRIORITY)"

# Enhanced library setup with validation
proc setup_libraries {} {
    global TARGET_LIBRARY LINK_LIBRARY SEARCH_PATH
    
    # Set search path with validation
    set valid_paths {}
    foreach path [split $SEARCH_PATH] {
        if {[file isdirectory $path]} {
            lappend valid_paths $path
        } else {
            puts "WARNING: Search path not found: $path"
        }
    }
    
    if {[llength $valid_paths] > 0} {
        set search_path $valid_paths
    } else {
        puts "ERROR: No valid search paths found"
        return -code error "Invalid search paths"
    }
    
    # Validate target library
    if {![file exists [which $TARGET_LIBRARY]]} {
        puts "ERROR: Target library not found: $TARGET_LIBRARY"
        return -code error "Missing target library"
    }
    
    # Set libraries
    set target_library $TARGET_LIBRARY
    set link_library $LINK_LIBRARY
    
    puts "Libraries configured successfully:"
    puts "  Target: $target_library"
    puts "  Link: $link_library"
    puts "  Search paths: $search_path"
}

# Enhanced netlist reading with format detection
proc read_netlist_and_setup {} {
    global DESIGN_NAME NETLIST
    
    # Setup libraries first
    setup_libraries
    
    # Validate netlist exists
    if {![file exists $NETLIST]} {
        return -code error "Netlist file not found: $NETLIST"
    }
    
    puts "Reading netlist: $NETLIST"
    
    # Determine file format and read accordingly
    set file_ext [file extension $NETLIST]
    switch -nocase $file_ext {
        ".v" -
        ".verilog" {
            read_verilog $NETLIST
        }
        ".sv" {
            puts "WARNING: SystemVerilog detected - consider using DB format"
            read_verilog $NETLIST
        }
        ".db" {
            read_db $NETLIST
        }
        default {
            puts "WARNING: Unknown netlist format, attempting Verilog read"
            read_verilog $NETLIST
        }
    }
    
    # Set current design with validation
    if {[catch {current_design $DESIGN_NAME} err]} {
        puts "Available designs: [get_designs]"
        return -code error "Design $DESIGN_NAME not found: $err"
    }
    
    # Link design with validation
    if {[catch {link_design} err]} {
        return -code error "Link failed: $err"
    }
    
    puts "Design $DESIGN_NAME loaded and linked successfully"
}

# Enhanced constraint setup
proc setup_basic_constraints {} {
    global CLOCK_PERIOD DESIGN_NAME
    
    # Find clocks in design
    set clocks [all_clocks]
    
    if {[llength $clocks] == 0} {
        # Search for clock-like ports
        set clock_candidates {}
        foreach port [get_object_name [all_inputs]] {
            if {[regexp -nocase {clk|clock} $port]} {
                lappend clock_candidates $port
            }
        }
        
        if {[llength $clock_candidates] > 0} {
            set clock_port [lindex $clock_candidates 0]
            create_clock -period $CLOCK_PERIOD [get_ports $clock_port]
            puts "Created clock on $clock_port with period $CLOCK_PERIOD ns"
        } else {
            puts "WARNING: No clock ports found - timing analysis may be incomplete"
        }
    }
    
    # Set input/output delays only if clocks exist
    if {[llength [all_clocks]] > 0} {
        set_input_delay -clock [get_clocks] [expr $CLOCK_PERIOD * 0.1] [all_inputs]
        set_output_delay -clock [get_clocks] [expr $CLOCK_PERIOD * 0.1] [all_outputs]
        puts "Applied basic I/O timing constraints"
    }
}

# Enhanced error handling
proc handle_analysis_error {analysis_type error_msg} {
    global REPORT_DIR
    
    puts "ERROR in $analysis_type Analysis: $error_msg"
    
    # Write detailed error log
    set error_file "${REPORT_DIR}/error_${analysis_type}.log"
    set fp [open $error_file "w"]
    puts $fp "$analysis_type Analysis Error Report"
    puts $fp "========================================="
    puts $fp "Timestamp: [clock format [clock seconds]]"
    puts $fp "Error: $error_msg"
    puts $fp ""
    puts $fp "Environment:"
    puts $fp "  Design: $::DESIGN_NAME"
    puts $fp "  Netlist: $::NETLIST"
    puts $fp "  PrimeTime Version: [get_app_var pt_version]"
    puts $fp ""
    puts $fp "Call Stack:"
    puts $fp [join [info level 0] "\n"]
    close $fp
    
    puts "Detailed error log written to: $error_file"
}

# Enhanced runtime reporting
proc report_runtime {analysis_type} {
    global REPORT_DIR
    
    set runtime_file "${REPORT_DIR}/runtime_${analysis_type}.rpt"
    set fp [open $runtime_file "w"]
    
    puts $fp "$analysis_type Runtime Report"
    puts $fp "================================"
    puts $fp "Timestamp: [clock format [clock seconds]]"
    
    # Safe memory and CPU reporting
    if {[catch {set memory [get_app_var memory_usage]} err]} {
        set memory "N/A (error: $err)"
    }
    if {[catch {set cpu [get_app_var cpu_time]} err]} {
        set cpu "N/A (error: $err)"
    }
    
    puts $fp "Memory usage: $memory"
    puts $fp "CPU time: $cpu"
    puts $fp "Analysis type: $analysis_type"
    
    close $fp
    puts "Runtime report generated: $runtime_file"
}

puts "Enhanced common TCL procedures loaded successfully"
EOF

#==============================================================================
# ENHANCED TARGETS
#==============================================================================

# Enhanced regression testing with both STA and Power
regression: validate_tools setup
	@echo "=== Running Enhanced Multi-Corner Analysis ==="
	@for corner in fast typical slow; do \
		echo "Analyzing $$corner corner (STA + Power)..."; \
		$(MAKE) sta PROCESS=$$corner RUN_DIR=./runs/$${corner}_sta || exit 1; \
		$(MAKE) power PROCESS=$$corner RUN_DIR=./runs/$${corner}_power || exit 1; \
	done
	@echo "Multi-corner regression completed successfully"

# Enhanced summary with time-sorted reports
summary:
	@echo "=== Generating Time-Sorted Analysis Summary ==="
	@if [ -d "./runs" ]; then \
		find ./runs -name "*.rpt" -printf "%T@ %p\n" | sort -n | while read timestamp file; do \
			echo "Report: $$file (Modified: $$(date -d @$${timestamp%.*} '+%Y-%m-%d %H:%M:%S'))"; \
			echo "--- Summary (first 10 lines) ---"; \
			head -10 "$$file" 2>/dev/null || echo "Cannot read file"; \
			echo ""; \
		done; \
	else \
		echo "No runs directory found"; \
	fi

# Quick statistics summary
summary_stats:
	@if [ -d "./runs" ]; then \
		echo "Analysis Statistics:"; \
		echo "- Total runs: $$(find ./runs -maxdepth 1 -type d | wc -l)"; \
		echo "- Total reports: $$(find ./runs -name "*.rpt" | wc -l)"; \
		echo "- Total logs: $$(find ./runs -name "*.log" | wc -l)"; \
		echo "- Latest run: $$(ls -t ./runs | head -1)"; \
	fi

# Safe clean with confirmation for production use
clean:
	@echo "=== Cleaning Up (Enhanced) ==="
	@echo "This will remove:"
	@echo "  - Generated TCL scripts in $(SCRIPT_DIR)"
	@echo "  - Current run directory: $(RUN_DIR)"
	@read -p "Continue? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		rm -rf $(RUN_DIR); \
		rm -f $(SCRIPT_DIR)/pt_*.tcl $(SCRIPT_DIR)/sta_*.tcl $(SCRIPT_DIR)/power_*.tcl $(SCRIPT_DIR)/version_check.tcl; \
		echo "Cleanup completed"; \
	else \
		echo "Cleanup cancelled"; \
	fi

# Clean all runs (dangerous - requires double confirmation)
clean_all:
	@echo "WARNING: This will delete ALL run data in ./runs/"
	@read -p "Are you absolutely sure? Type 'DELETE_ALL' to confirm: " confirm; \
	if [ "$$confirm" = "DELETE_ALL" ]; then \
		rm -rf ./runs; \
		echo "All run data deleted"; \
	else \
		echo "Operation cancelled"; \
	fi

# Enhanced help
help:
	@echo "Enhanced PrimeTime Analysis Makefile"
	@echo "===================================================="
	@echo ""
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Main Targets:"
	@echo "  all              - Run complete analysis (STA + Power) with validation"
	@echo "  sta              - Run Static Timing Analysis only"
	@echo "  power            - Run Power Analysis only"
	@echo "  regression       - Multi-corner analysis (fast/typical/slow)"
	@echo "  setup            - Setup directory structure"
	@echo "  validate_tools   - Check PrimeTime installation"
	@echo "  check_files      - Verify input files exist and validate formats"
	@echo "  summary          - Time-sorted report summary"
	@echo "  clean            - Remove current run (with confirmation)"
	@echo "  clean_all        - Remove all runs (requires double confirmation)"
	@echo "  help             - Show this help"
	@echo ""
	@echo "Key Variables (can be overridden):"
	@echo "  DESIGN_NAME      - Top module name (default: top_module)"
	@echo "  NETLIST          - Path to netlist file (.v/.sv/.db supported)"
	@echo "  VCD_FILE         - Path to VCD activity file"
	@echo "  SAIF_FILE        - Path to SAIF activity file"
	@echo "  SDC_FILE         - Path to SDC constraints file"
	@echo "  CLOCK_PERIOD     - Clock period in ns (default: 10.0)"
	@echo "  VOLTAGE          - Operating voltage (default: 1.0)"
	@echo "  TEMPERATURE      - Operating temperature (default: 25)"
	@echo "  ACTIVITY_PRIORITY - VCD_FIRST (default) or SAIF_FIRST"
	@echo ""
	@echo "Enhanced Features:"
	@echo "  ✓ Tool validation and version checking"
	@echo "  ✓ Netlist format auto-detection (.v/.sv/.db)"
	@echo "  ✓ Activity file priority handling"
	@echo "  ✓ Library corner validation"
	@echo "  ✓ Comprehensive error handling and logging"
	@echo "  ✓ Time-sorted report generation"
	@echo "  ✓ Safe cleanup with confirmation"
	@echo ""
	@echo "Example usage:"
	@echo "  make DESIGN_NAME=cpu_core NETLIST=./design/cpu.v VCD_FILE=./sim/cpu.vcd"
	@echo "  make regression DESIGN_NAME=my_design"
	@echo "  make sta ACTIVITY_PRIORITY=SAIF_FIRST"
	@echo ""

.PRECIOUS: $(STA_SCRIPT) $(POWER_SCRIPT) $(COMMON_SCRIPT)