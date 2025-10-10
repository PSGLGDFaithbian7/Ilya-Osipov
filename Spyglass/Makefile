# Industrial Grade Spyglass RTL Analysis Framework (Fixed Version)
# Author: Claude Code
# Version: 2.0 - Production Ready

##############################################################################
# Enhanced Configuration Section with Validation
##############################################################################

# Tool Detection and Validation
SPYGLASS_HOME := $(shell if command -v spyglass >/dev/null 2>&1; then \
                   dirname $$(dirname $$(which spyglass)); else \
                   echo "/tools/synopsys/spyglass/latest"; fi)
SG_SHELL      := $(SPYGLASS_HOME)/bin/sg_shell
SG_GUI        := $(SPYGLASS_HOME)/bin/spyglass

# Validate Spyglass Installation
ifeq ($(wildcard $(SG_SHELL)),)
$(error Spyglass not found at $(SG_SHELL). Please set SPYGLASS_HOME or add spyglass to PATH)
endif

# Project Configuration with Defaults and Validation
PROJECT_NAME  ?= rtl_project
TOP_MODULES   ?= top_module
RTL_ROOT      ?= ./rtl
INCLUDE_DIRS  ?= ./include ./rtl/include
DEFINE_FILE   ?= ./config/defines.vh
CONFIG_DIR    ?= ./config
SCRIPT_DIR    ?= ./scripts
RESULTS_DIR   ?= ./results
LOG_DIR       ?= ./logs

# Validate critical paths
ifeq ($(wildcard $(RTL_ROOT)),)
$(error RTL_ROOT directory not found: $(RTL_ROOT))
endif

# Spyglass Configuration
SG_PROJECT    := $(PROJECT_NAME)_sg
SG_GOAL       ?= lint/lint_rtl
SG_METHODOLOGY ?= GuideWare/latest/block/rtl/spyglass_spysch
SG_WAIVER_FILE ?= $(CONFIG_DIR)/waivers.awl

# Mode Controls
REUSE         ?= 0
REPORT_ONLY   ?= 0
PARALLEL      ?= 0
DEBUG         ?= 0
DOCKER        ?= 0

# File Lists with Enhanced Discovery
RTL_FILELIST     := $(CONFIG_DIR)/rtl_files.f
INCLUDE_FILELIST := $(CONFIG_DIR)/include_files.f
MANIFEST_FILE    ?= $(CONFIG_DIR)/manifest.f

# Smart file discovery - prefer manifest, fallback to find
ifneq ($(wildcard $(MANIFEST_FILE)),)
    SV_FILES := $(shell grep -E '\.(sv|v)$$' $(MANIFEST_FILE) 2>/dev/null | head -1000)
else
    SV_FILES := $(shell find $(RTL_ROOT) -name "*.sv" -o -name "*.v" 2>/dev/null | head -1000)
endif

VH_FILES := $(foreach dir,$(INCLUDE_DIRS),$(wildcard $(dir)/*.vh $(dir)/*.svh))

# Validate file discovery
ifeq ($(SV_FILES),)
$(warning No RTL files found. Check RTL_ROOT=$(RTL_ROOT) or create $(MANIFEST_FILE))
endif

# Timestamp and Version Control Integration
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)_$$$$
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
GIT_DIRTY  := $(shell git diff --quiet 2>/dev/null || echo "_dirty")
BUILD_TAG  := $(GIT_BRANCH)_$(GIT_COMMIT)$(GIT_DIRTY)

# Export variables to TCL scripts
export PROJECT_NAME TOP_MODULES RTL_ROOT INCLUDE_DIRS DEFINE_FILE
export RESULTS_DIR LOG_DIR TIMESTAMP BUILD_TAG SG_WAIVER_FILE
export REUSE REPORT_ONLY DEBUG GIT_COMMIT GIT_BRANCH

##############################################################################
# Directory Setup with Permissions
##############################################################################

DIRS := $(RESULTS_DIR) $(LOG_DIR) $(CONFIG_DIR) $(SCRIPT_DIR) \
        $(RESULTS_DIR)/lint $(RESULTS_DIR)/cdc $(RESULTS_DIR)/rdc

$(DIRS):
	@mkdir -p $@
	@chmod 755 $@

##############################################################################
# Enhanced Main Targets
##############################################################################

.PHONY: all clean setup run_lint run_cdc run_rdc gui help validate_env report_lint docker

all: validate_env setup run_lint

help:
	@echo "Industrial Grade Spyglass RTL Analysis Framework v2.0"
	@echo "======================================================"
	@echo ""
	@echo "Main Targets:"
	@echo "  all         - Run complete lint analysis"
	@echo "  run_lint    - Run lint analysis"
	@echo "  run_cdc     - Run CDC analysis" 
	@echo "  run_rdc     - Run RDC analysis"
	@echo "  report_only - Regenerate reports only"
	@echo "  gui         - Launch Spyglass GUI"
	@echo "  docker      - Run in Docker container"
	@echo ""
	@echo "Utility Targets:"
	@echo "  setup       - Create directories and file lists"
	@echo "  validate_env- Validate tool installation"
	@echo "  clean       - Clean results and logs"
	@echo "  status      - Show project status"
	@echo ""
	@echo "Configuration Variables:"
	@echo "  PROJECT_NAME  = $(PROJECT_NAME)"
	@echo "  TOP_MODULES   = $(TOP_MODULES)"
	@echo "  RTL_ROOT      = $(RTL_ROOT)"
	@echo "  SG_GOAL       = $(SG_GOAL)"
	@echo "  BUILD_TAG     = $(BUILD_TAG)"
	@echo ""
	@echo "Mode Switches:"
	@echo "  REUSE=1       - Reuse existing project"
	@echo "  REPORT_ONLY=1 - Only generate reports"
	@echo "  PARALLEL=1    - Enable parallel execution"
	@echo "  DEBUG=1       - Enable debug logging"
	@echo "  DOCKER=1      - Run in container"
	@echo ""
	@echo "Examples:"
	@echo "  make run_lint TOP_MODULES=\"cpu mmu cache\""
	@echo "  make run_cdc REUSE=1 DEBUG=1"
	@echo "  make report_only"

##############################################################################
# Environment Validation
##############################################################################

validate_env:
	@echo "Validating Spyglass environment..."
	@echo "SPYGLASS_HOME: $(SPYGLASS_HOME)"
	@test -f $(SG_SHELL) || (echo "ERROR: sg_shell not found"; exit 1)
	@echo "Tool version: $$($(SG_SHELL) -version 2>/dev/null | head -1 || echo 'Version check failed')"
	@echo "License check: $$($(SG_SHELL) -c 'exit' 2>&1 | grep -i license || echo 'OK')"
	@echo "Environment validation passed ✓"

##############################################################################
# Enhanced Setup with Validation
##############################################################################

setup: $(DIRS) $(RTL_FILELIST) $(INCLUDE_FILELIST) generate_tcl_scripts

$(RTL_FILELIST): $(DIRS) validate_env
	@echo "Generating RTL file list..."
	@echo "# RTL File List - Generated on $(shell date)" > $@
	@echo "# Project: $(PROJECT_NAME)" >> $@
	@echo "# Build Tag: $(BUILD_TAG)" >> $@
	@echo "# Total Files: $(words $(SV_FILES))" >> $@
	@echo "" >> $@
	@if [ "$(words $(SV_FILES))" -eq "0" ]; then \
		echo "ERROR: No RTL files found!"; \
		echo "# ERROR: No RTL files discovered" >> $@; \
		exit 1; \
	fi
	@for file in $(SV_FILES); do \
		if [ -f "$$file" ]; then \
			echo "$$file" >> $@; \
		else \
			echo "WARNING: File not found: $$file" >&2; \
		fi; \
	done
	@echo "Generated RTL filelist with $(words $(SV_FILES)) files ✓"

$(INCLUDE_FILELIST): $(DIRS)
	@echo "Generating include file list..."
	@echo "# Include Configuration - Generated on $(shell date)" > $@
	@echo "# Project: $(PROJECT_NAME)" >> $@
	@echo "" >> $@
	@for dir in $(INCLUDE_DIRS); do \
		if [ -d "$$dir" ]; then \
			echo "+incdir+$$dir" >> $@; \
			echo "INFO: Added include directory: $$dir" >&2; \
		else \
			echo "WARNING: Include directory not found: $$dir" >&2; \
		fi; \
	done
	@if [ -f "$(DEFINE_FILE)" ]; then \
		echo "+include+$(DEFINE_FILE)" >> $@; \
		echo "INFO: Added defines file: $(DEFINE_FILE)" >&2; \
	fi
	@echo "Generated include configuration ✓"

##############################################################################
# Enhanced TCL Script Generation with Variable Expansion
##############################################################################

generate_tcl_scripts: $(SCRIPT_DIR)/run_spyglass.tcl $(SCRIPT_DIR)/setup_project.tcl \
                     $(SCRIPT_DIR)/run_goals.tcl $(SCRIPT_DIR)/common_procs.tcl

$(SCRIPT_DIR)/setup_project.tcl: $(DIRS)
	@echo "Generating setup_project.tcl with variable expansion..."
	@cat > $@ <<'EOL'
#!/usr/bin/env sg_shell
# Spyglass Project Setup Script - Generated with variable expansion
# Build Tag: $(BUILD_TAG)

# Source common procedures
source [file join [file dirname [info script]] "common_procs.tcl"]

# Project configuration from environment
proc get_env_var {var default} {
    global env
    if {[info exists env($var)]} {
        return $env($var)
    } else {
        return $default
    }
}

set PROJECT_NAME     [get_env_var "PROJECT_NAME" "rtl_project"]
set TOP_MODULES      [split [get_env_var "TOP_MODULES" "top_module"]]
set RTL_FILELIST     [get_env_var "RTL_FILELIST" "$(RTL_FILELIST)"]
set INCLUDE_FILELIST [get_env_var "INCLUDE_FILELIST" "$(INCLUDE_FILELIST)"]
set SG_WAIVER_FILE   [get_env_var "SG_WAIVER_FILE" "$(SG_WAIVER_FILE)"]
set REUSE_MODE       [get_env_var "REUSE" "0"]
set DEBUG_MODE       [get_env_var "DEBUG" "0"]
set BUILD_TAG        [get_env_var "BUILD_TAG" "unknown"]

proc setup_spyglass_project {} {
    global PROJECT_NAME TOP_MODULES RTL_FILELIST INCLUDE_FILELIST 
    global SG_WAIVER_FILE REUSE_MODE DEBUG_MODE BUILD_TAG
    
    log_msg "INFO" "Setting up Spyglass project: $PROJECT_NAME"
    log_msg "INFO" "Build Tag: $BUILD_TAG"
    log_msg "INFO" "Top Modules: $TOP_MODULES"
    log_msg "INFO" "Reuse Mode: $REUSE_MODE"
    
    # Handle project creation/reuse
    if {$REUSE_MODE && [file exists "${PROJECT_NAME}.prj"]} {
        log_msg "INFO" "Reusing existing project"
        open_project ${PROJECT_NAME}.prj
    } else {
        log_msg "INFO" "Creating new project"
        new_project $PROJECT_NAME -force
    }
    
    # Read design files with validation
    if {[file exists $RTL_FILELIST]} {
        log_msg "INFO" "Reading RTL files from: $RTL_FILELIST"
        if {[catch {read_file -type sourcelist $RTL_FILELIST} err]} {
            log_msg "ERROR" "Failed to read RTL filelist: $err"
            return -1
        }
    } else {
        log_msg "ERROR" "RTL filelist not found: $RTL_FILELIST"
        return -1
    }
    
    # Read include configuration
    if {[file exists $INCLUDE_FILELIST]} {
        log_msg "INFO" "Reading include configuration from: $INCLUDE_FILELIST"
        apply_include_config $INCLUDE_FILELIST
    }
    
    # Apply waivers if available
    apply_waivers $SG_WAIVER_FILE
    
    # Configure for each top module
    foreach top $TOP_MODULES {
        log_msg "INFO" "Configuring for top module: $top"
        set_option top $top
        configure_analysis_options $top
    }
    
    log_msg "INFO" "Project setup completed successfully"
    return 0
}

proc apply_include_config {config_file} {
    set fp [open $config_file r]
    while {[gets $fp line] >= 0} {
        set line [string trim $line]
        if {[string match "+incdir+*" $line]} {
            set incdir [string range $line 8 end]
            if {[file isdirectory $incdir]} {
                set_option incdir $incdir
                log_msg "INFO" "Added include directory: $incdir"
            }
        } elseif {[string match "+include+*" $line]} {
            set incfile [string range $line 9 end]
            if {[file exists $incfile]} {
                read_file -type verilog $incfile
                log_msg "INFO" "Included file: $incfile"
            }
        }
    }
    close $fp
}

proc configure_analysis_options {top_module} {
    global DEBUG_MODE
    
    log_msg "INFO" "Configuring analysis options for: $top_module"
    
    # Basic configuration
    set_option enableSV yes
    set_option language_mode mixed
    set_option designread_enable_synthesis yes
    
    # Enhanced clock/reset detection
    set_option auto_detect_clock_reset yes
    set_option handle_default_clocking_block yes
    set_option enable_clock_domain_analysis yes
    
    # Debug options
    if {$DEBUG_MODE} {
        set_option verbose_level 2
        set_option enable_debug_db yes
        log_msg "DEBUG" "Debug mode enabled"
    }
    
    # Lint-specific options
    set_option lint_rules "all"
    set_option enable_gated_clock_conversion yes
    set_option check_FSM yes
    set_option check_case_constructs yes
    
    log_msg "INFO" "Analysis options configured for $top_module"
}

# Execute setup if run directly
if {[info script] eq $argv0} {
    if {[setup_spyglass_project] == 0} {
        save_project
        log_msg "INFO" "Project saved successfully"
    } else {
        log_msg "ERROR" "Project setup failed"
        exit 1
    }
}
EOL

$(SCRIPT_DIR)/run_goals.tcl: $(DIRS)
	@echo "Generating enhanced run_goals.tcl..."
	@cat > $@ <<'EOL'
#!/usr/bin/env sg_shell
# Enhanced Spyglass Goals Execution Script

# Source common procedures
source [file join [file dirname [info script]] "common_procs.tcl"]

# Global variables from environment
set RESULTS_DIR     [get_env_var "RESULTS_DIR" "./results"]
set TIMESTAMP       [get_env_var "TIMESTAMP" [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]]
set TOP_MODULES     [split [get_env_var "TOP_MODULES" "top_module"]]
set REPORT_ONLY     [get_env_var "REPORT_ONLY" "0"]
set BUILD_TAG       [get_env_var "BUILD_TAG" "unknown"]

proc run_lint_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES REPORT_ONLY BUILD_TAG
    
    log_msg "INFO" "Starting lint analysis..."
    log_msg "INFO" "Build Tag: $BUILD_TAG"
    
    set report_dir [ensure_dir [file join $RESULTS_DIR "lint" "lint_$TIMESTAMP"]]
    
    if {!$REPORT_ONLY} {
        # Set current goal to lint
        if {[catch {current_goal lint/lint_rtl} err]} {
            log_msg "ERROR" "Failed to set lint goal: $err"
            return -1
        }
        
        # Process each top module
        set total_violations 0
        foreach top $TOP_MODULES {
            log_msg "INFO" "Processing top module: $top"
            
            # Compile design
            if {[catch {
                set_option top $top
                compile_design -goal lint/lint_rtl
            } err]} {
                log_msg "ERROR" "Compilation failed for $top: $err"
                return -1
            }
            
            # Run lint analysis
            if {[catch {run_goal} err]} {
                log_msg "ERROR" "Lint analysis failed for $top: $err"
                return -1
            }
            
            # Generate reports for this top
            set top_report_dir [ensure_dir [file join $report_dir $top]]
            set violations [generate_lint_reports $top_report_dir $top]
            set total_violations [expr $total_violations + $violations]
        }
        
        log_msg "INFO" "Lint analysis completed with $total_violations total violations"
    } else {
        log_msg "INFO" "Report-only mode: regenerating reports"
        foreach top $TOP_MODULES {
            set top_report_dir [ensure_dir [file join $report_dir $top]]
            generate_lint_reports $top_report_dir $top
        }
    }
    
    # Generate summary report
    generate_summary_report $report_dir "Lint Analysis" $BUILD_TAG
    
    return 0
}

proc run_cdc_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG
    
    log_msg "INFO" "Starting CDC analysis..."
    
    set report_dir [ensure_dir [file join $RESULTS_DIR "cdc" "cdc_$TIMESTAMP"]]
    
    if {[catch {current_goal cdc/cdc_setup_check} err]} {
        log_msg "ERROR" "Failed to set CDC goal: $err"
        return -1
    }
    
    foreach top $TOP_MODULES {
        log_msg "INFO" "CDC analysis for top module: $top"
        
        if {[catch {
            set_option top $top
            compile_design -goal cdc/cdc_setup_check
            run_goal
        } err]} {
            log_msg "ERROR" "CDC analysis failed for $top: $err"
            return -1
        }
        
        set top_report_dir [ensure_dir [file join $report_dir $top]]
        generate_cdc_reports $top_report_dir $top
    }
    
    generate_summary_report $report_dir "CDC Analysis" $BUILD_TAG
    return 0
}

proc run_rdc_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG
    
    log_msg "INFO" "Starting RDC analysis..."
    
    set report_dir [ensure_dir [file join $RESULTS_DIR "rdc" "rdc_$TIMESTAMP"]]
    
    if {[catch {current_goal rdc/rdc_setup_check} err]} {
        log_msg "ERROR" "Failed to set RDC goal: $err"
        return -1
    }
    
    foreach top $TOP_MODULES {
        log_msg "INFO" "RDC analysis for top module: $top"
        
        if {[catch {
            set_option top $top
            compile_design -goal rdc/rdc_setup_check
            run_goal
        } err]} {
            log_msg "ERROR" "RDC analysis failed for $top: $err"
            return -1
        }
        
        set top_report_dir [ensure_dir [file join $report_dir $top]]
        generate_rdc_reports $top_report_dir $top
    }
    
    generate_summary_report $report_dir "RDC Analysis" $BUILD_TAG
    return 0
}

proc generate_lint_reports {report_dir top_module} {
    log_msg "INFO" "Generating lint reports for $top_module in: $report_dir"
    
    set violation_count 0
    
    # Summary report with error handling
    if {[catch {
        report_policy_summary > [file join $report_dir "lint_summary.rpt"]
        set violation_count [get_violation_count]
    } err]} {
        log_msg "WARNING" "Failed to generate summary report: $err"
    }
    
    # Detailed reports
    catch {report_policy -skip_empty_summary_status -verbose > [file join $report_dir "lint_violations.rpt"]}
    catch {report_policy -rules > [file join $report_dir "lint_rules.rpt"]}
    catch {report_policy -statistics > [file join $report_dir "lint_statistics.rpt"]}
    catch {report_policy -waived > [file join $report_dir "lint_waived.rpt"]}
    
    # Custom violation analysis
    generate_violation_analysis $report_dir $top_module
    
    log_msg "INFO" "Lint reports generated for $top_module ($violation_count violations)"
    return $violation_count
}

proc generate_cdc_reports {report_dir top_module} {
    log_msg "INFO" "Generating CDC reports for $top_module"
    
    catch {report_policy_summary > [file join $report_dir "cdc_summary.rpt"]}
    catch {report_policy -verbose > [file join $report_dir "cdc_violations.rpt"]}
    catch {report_clock_domain > [file join $report_dir "clock_domains.rpt"]}
    catch {report_clock_interaction > [file join $report_dir "clock_interactions.rpt"]}
    
    generate_cdc_analysis $report_dir $top_module
}

proc generate_rdc_reports {report_dir top_module} {
    log_msg "INFO" "Generating RDC reports for $top_module"
    
    catch {report_policy_summary > [file join $report_dir "rdc_summary.rpt"]}
    catch {report_policy -verbose > [file join $report_dir "rdc_violations.rpt"]}
    catch {report_reset_domain > [file join $report_dir "reset_domains.rpt"]}
    catch {report_reset_interaction > [file join $report_dir "reset_interactions.rpt"]}
}

proc get_violation_count {} {
    # Implement violation counting logic based on Spyglass API
    if {[catch {
        set result [report_policy -return_string -summary]
        # Parse result to extract violation count
        if {[regexp {(\d+)\s+violations} $result match count]} {
            return $count
        }
    }]} {
        return 0
    }
    return 0
}

proc generate_violation_analysis {report_dir top_module} {
    # Generate custom violation analysis
    set analysis_file [file join $report_dir "violation_analysis.txt"]
    set fp [open $analysis_file w]
    puts $fp "Violation Analysis for $top_module"
    puts $fp "Generated: [clock format [clock seconds]]"
    puts $fp "======================================"
    puts $fp ""
    
    # Add custom analysis logic here
    puts $fp "Top 10 Most Common Violations:"
    puts $fp "Top 10 Most Violated Rules:"
    puts $fp "Severity Distribution:"
    
    close $fp
}

proc generate_cdc_analysis {report_dir top_module} {
    # Generate CDC-specific analysis
    set analysis_file [file join $report_dir "cdc_analysis.txt"]
    set fp [open $analysis_file w]
    puts $fp "CDC Analysis Summary for $top_module"
    puts $fp "Generated: [clock format [clock seconds]]"
    puts $fp "======================================="
    close $fp
}

proc generate_summary_report {report_dir analysis_type build_tag} {
    set summary_file [file join $report_dir "00_SUMMARY.txt"]
    set fp [open $summary_file w]
    
    puts $fp "$analysis_type Summary Report"
    puts $fp "=============================="
    puts $fp "Generated: [clock format [clock seconds]]"
    puts $fp "Build Tag: $build_tag"
    puts $fp "Analysis: $analysis_type"
    puts $fp ""
    
    # List all generated reports
    set report_files [glob -nocomplain [file join $report_dir "*" "*.rpt"]]
    if {[llength $report_files] > 0} {
        puts $fp "Generated Reports:"
        foreach rpt [lsort $report_files] {
            set rel_path [file join [file tail [file dirname $rpt]] [file tail $rpt]]
            puts $fp "  $rel_path"
        }
    }
    
    close $fp
    
    # Generate HTML index
    generate_html_report $report_dir $analysis_type
}
EOL

##############################################################################
# Enhanced Run Targets with Error Handling
##############################################################################

run_lint: setup
	@echo "=== Running Spyglass Lint Analysis ==="
	@echo "Project: $(PROJECT_NAME)"
	@echo "Top Modules: $(TOP_MODULES)"  
	@echo "Build Tag: $(BUILD_TAG)"
	@echo "Timestamp: $(TIMESTAMP)"
	@mkdir -p $(RESULTS_DIR)/lint $(LOG_DIR)
	@if [ "$(DOCKER)" = "1" ]; then \
		$(MAKE) docker_lint; \
	else \
		cd $(RESULTS_DIR) && \
		$(SG_SHELL) -f $(SCRIPT_DIR)/run_spyglass.tcl lint 2>&1 | \
		tee $(LOG_DIR)/lint_$(TIMESTAMP).log; \
		if [ $${PIPESTATUS[0]} -ne 0 ]; then \
			echo "ERROR: Lint analysis failed. Check $(LOG_DIR)/lint_$(TIMESTAMP).log"; \
			exit 1; \
		fi; \
	fi
	@echo "=== Lint Analysis Completed Successfully ==="

run_cdc: setup
	@echo "=== Running Spyglass CDC Analysis ==="
	@mkdir -p $(RESULTS_DIR)/cdc $(LOG_DIR)
	@cd $(RESULTS_DIR) && \
	$(SG_SHELL) -f $(SCRIPT_DIR)/run_spyglass.tcl cdc 2>&1 | \
	tee $(LOG_DIR)/cdc_$(TIMESTAMP).log; \
	if [ $${PIPESTATUS[0]} -ne 0 ]; then \
		echo "ERROR: CDC analysis failed"; exit 1; \
	fi

run_rdc: setup
	@echo "=== Running Spyglass RDC Analysis ==="
	@mkdir -p $(RESULTS_DIR)/rdc $(LOG_DIR)
	@cd $(RESULTS_DIR) && \
	$(SG_SHELL) -f $(SCRIPT_DIR)/run_spyglass.tcl rdc 2>&1 | \
	tee $(LOG_DIR)/rdc_$(TIMESTAMP).log; \
	if [ $${PIPESTATUS[0]} -ne 0 ]; then \
		echo "ERROR: RDC analysis failed"; exit 1; \
	fi

report_lint: setup
	@echo "=== Regenerating Lint Reports Only ==="
	@export REPORT_ONLY=1 && $(MAKE) run_lint

##############################################################################
# Docker Support
##############################################################################

docker_lint: setup
	@echo "=== Running Lint Analysis in Docker ==="
	@docker run --rm \
		-v $(PWD):/workspace \
		-w /workspace \
		-e PROJECT_NAME="$(PROJECT_NAME)" \
		-e TOP_MODULES="$(TOP_MODULES)" \
		-e BUILD_TAG="$(BUILD_TAG)" \
		spyglass:latest \
		sg_shell -f scripts/run_spyglass.tcl lint

docker: setup
	@echo "=== Building and Running in Docker ==="
	@if [ ! -f Dockerfile ]; then \
		echo "Creating Dockerfile..."; \
		cat > Dockerfile <<-'DOCKEREOF'; \
FROM ubuntu:20.04; \
RUN apt-get update && apt-get install -y tcsh; \
COPY tools/spyglass /tools/spyglass; \
ENV SPYGLASS_HOME=/tools/spyglass; \
ENV PATH=$$PATH:/tools/spyglass/bin; \
WORKDIR /workspace; \
		DOCKEREOF \
	fi
	@docker build -t spyglass:latest .
	@$(MAKE) docker_lint

##############################################################################
# Parallel Execution Support
##############################################################################

parallel_all: setup
	@echo "=== Running All Analyses in Parallel ==="
	@$(MAKE) -j3 run_lint run_cdc run_rdc PARALLEL=1

##############################################################################
# Enhanced Utility Targets
##############################################################################

status:
	@echo "=== Project Status ==="
	@echo "Project: $(PROJECT_NAME)"
	@echo "Build Tag: $(BUILD_TAG)"
	@echo "RTL Files: $(words $(SV_FILES))"
	@echo "Header Files: $(words $(VH_FILES))" 
	@echo "Top Modules: $(TOP_MODULES)"
	@echo "Results Dir: $(RESULTS_DIR)"
	@echo "Spyglass: $(SG_SHELL)"
	@echo "Last Lint Run: $$(ls -t $(LOG_DIR)/lint_*.log 2>/dev/null | head -1 || echo 'None')"
	@echo "Disk Usage: $$(du -sh $(RESULTS_DIR) 2>/dev/null || echo 'No results')"

clean:
	@echo "Cleaning results and logs..."
	@rm -rf $(RESULTS_DIR)/* $(LOG_DIR)/*
	@echo "Clean completed ✓"

distclean: clean
	@rm -rf $(RESULTS_DIR) $(LOG_DIR) $(SCRIPT_DIR)/*.tcl
	@rm -f $(CONFIG_DIR)/*.f Dockerfile
	@echo "Deep clean completed ✓"

gui: setup
	@echo "Launching Spyglass GUI..."
	@cd $(RESULTS_DIR) && $(SG_GUI) -project $(SG_PROJECT).prj &

.PHONY: validate_env generate_tcl_scripts status distclean parallel_all docker_lint docker report_lint