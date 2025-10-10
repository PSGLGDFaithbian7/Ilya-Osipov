#!/usr/bin/env sg_shell
# Main Spyglass Runner - Standalone TCL File

set script_dir [file dirname [info script]]

# Source all required scripts
source [file join $script_dir "common_procs.tcl"]
source [file join $script_dir "setup_project.tcl"]
source [file join $script_dir "run_goals.tcl"]

##############################################################################
# Main Execution
##############################################################################

proc main {goal_type} {
    log_msg "INFO" "=== Spyglass Runner Started ==="
    log_msg "INFO" "Goal: $goal_type"
    
    # Setup project
    load_config_from_env
    if {[setup_spyglass_project] != 0} {
        log_msg "ERROR" "Project setup failed"
        return 1
    }
    
    # Load goal configuration
    load_goal_config
    
    # Run requested goal
    set result -1
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
    
    log_msg "INFO" "=== Spyglass Runner Finished ==="
    return $result
}

# Entry point
if {[llength $argv] < 1} {
    log_msg "ERROR" "Usage: sg_shell -source run_spyglass.tcl <lint|cdc|rdc>"
    exit 1
}

set goal [lindex $argv 0]
exit [main $goal]