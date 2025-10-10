#!/usr/bin/env sg_shell
# Main Spyglass Runner - P-2019 Compatible with Enhanced Debugging

puts "DEBUG: run_spyglass.tcl started"
puts "DEBUG: Script path: [info script]"
puts "DEBUG: Working directory: [pwd]"
puts "DEBUG: Arguments: $argv"

set script_dir [file dirname [info script]]
puts "DEBUG: Script directory: $script_dir"

# Source all required scripts
puts "DEBUG: Sourcing common_procs.tcl..."
source [file join $script_dir "common_procs.tcl"]
puts "DEBUG: common_procs.tcl loaded"

puts "DEBUG: Sourcing setup_project.tcl..."
source [file join $script_dir "setup_project.tcl"]
puts "DEBUG: setup_project.tcl loaded"

puts "DEBUG: Sourcing run_goals.tcl..."
source [file join $script_dir "run_goals.tcl"]
puts "DEBUG: run_goals.tcl loaded"

##############################################################################
# Main Execution
##############################################################################

proc main {goal_type} {
    log_msg "INFO" "========================================="
    log_msg "INFO" "Spyglass Runner Started"
    log_msg "INFO" "Goal: $goal_type"
    log_msg "INFO" "========================================="
    
    # Setup project
    load_config_from_env
    if {[setup_spyglass_project] != 0} {
        log_msg "ERROR" "Project setup failed"
        return 1
    }
    
    # Load goal configuration (already loaded at source time, but ensure it's current)
    load_goal_config
    
    # Run requested goal
    set result 1
    switch $goal_type {
        "lint" {
            set result [run_lint_goal]
        }
        "cdc" {
            set result [run_cdc_goal]
        }
        "rdc" {
            set result [run_rdc_goal]
        }
        default {
            log_msg "ERROR" "Unknown goal: $goal_type"
            log_msg "INFO" "Valid goals: lint, cdc, rdc"
            return 1
        }
    }
    
    # Save project
    if {$result == 0} {
        log_msg "INFO" "Goal completed successfully"
        if {[catch {save_project} err]} {
            log_msg "WARNING" "Failed to save project: $err"
        }
    } else {
        log_msg "ERROR" "Goal failed with code: $result"
    }
    
    log_msg "INFO" "========================================="
    log_msg "INFO" "Spyglass Runner Finished"
    log_msg "INFO" "========================================="
    return $result
}

##############################################################################
# Entry Point with Enhanced Debugging
##############################################################################

puts "DEBUG: Checking for goal specification..."

# First try environment variable
set goal [get_env_var "SG_GOAL" ""]
puts "DEBUG: SG_GOAL from environment: '$goal'"

# If not set, try command line
if {$goal eq ""} {
    puts "DEBUG: SG_GOAL not set, checking argv..."
    puts "DEBUG: argv length: [llength $argv]"
    puts "DEBUG: argv contents: $argv"
    
    if {[llength $argv] >= 1} {
        set goal [lindex $argv 0]
        puts "DEBUG: Goal from argv: '$goal'"
    } else {
        log_msg "ERROR" "No goal specified!"
        log_msg "ERROR" "Set SG_GOAL environment variable or pass as argument"
        log_msg "INFO" "Usage: SG_GOAL=lint sg_shell -tcl run_spyglass.tcl"
        puts "DEBUG: Exiting with code 1"
        exit 1
    }
} else {
    puts "DEBUG: Using goal from environment: '$goal'"
}

puts "DEBUG: About to call main function with goal: $goal"

# Execute main function
set exit_code [main $goal]
puts "DEBUG: main returned: $exit_code"

# Ensure exit code is valid
if {$exit_code < 0} {
    puts "DEBUG: Negative exit code detected, converting to 1"
    set exit_code 1
}

log_msg "INFO" "Exiting with code: $exit_code"
puts "DEBUG: About to exit with code: $exit_code"
exit $exit_code
