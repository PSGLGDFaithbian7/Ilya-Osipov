#!/usr/bin/env sg_shell
# Spyglass Goals Execution Script - P-2019 Production-Ready Version
# Author: System Integration Team
# Version: 3.0 - Handles all P-2019 quirks and edge cases

set script_dir [file dirname [info script]]
source [file join $script_dir "common_procs.tcl"]

##############################################################################
# Global Configuration
##############################################################################

proc load_goal_config {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG REPORT_ONLY
    
    set RESULTS_DIR [get_env_var "RESULTS_DIR" "./results"]
    set TIMESTAMP   [get_env_var "TIMESTAMP" [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]]
    set top_str     [get_env_var "TOP_MODULES" "top_module"]
    set TOP_MODULES [split $top_str]
    set BUILD_TAG   [get_env_var "BUILD_TAG" "unknown"]
    set REPORT_ONLY [get_env_var "REPORT_ONLY" "0"]
    
    log_msg "INFO" "Goal configuration loaded"
    log_msg "INFO" "  RESULTS_DIR: $RESULTS_DIR"
    log_msg "INFO" "  TIMESTAMP: $TIMESTAMP"
    log_msg "INFO" "  TOP_MODULES: $TOP_MODULES"
    log_msg "INFO" "  BUILD_TAG: $BUILD_TAG"
    log_msg "INFO" "  REPORT_ONLY: $REPORT_ONLY"
}

##############################################################################
# Universal Report Generation Engine (P-2019 Compatible)
##############################################################################

proc write_report_to_file {report_cmd file_path description} {
    log_msg "INFO" "Generating: $description"
    log_msg "INFO" "  Command: $report_cmd"
    log_msg "INFO" "  Output: $file_path"
    
    set success 0
    set methods_tried 0
    
    # Method 1: Standard output redirection (most common)
    if {!$success} {
        incr methods_tried
        log_msg "DEBUG" "  Trying method 1: Standard redirection (>)"
        if {[catch {
            eval "$report_cmd > \{$file_path\}"
            if {[file exists $file_path] && [file size $file_path] > 0} {
                set size [file size $file_path]
                log_msg "INFO" "  SUCCESS (Method 1): ${size} bytes"
                set success 1
            }
        } err]} {
            log_msg "DEBUG" "  Method 1 failed: $err"
        }
    }
    
    # Method 2: Using redirect command (P-2019 alternative)
    if {!$success} {
        incr methods_tried
        log_msg "DEBUG" "  Trying method 2: redirect command"
        if {[catch {
            redirect $file_path [list eval $report_cmd]
            if {[file exists $file_path] && [file size $file_path] > 0} {
                set size [file size $file_path]
                log_msg "INFO" "  SUCCESS (Method 2): ${size} bytes"
                set success 1
            }
        } err]} {
            log_msg "DEBUG" "  Method 2 failed: $err"
        }
    }
    
    # Method 3: Using -return_string and manual file write
    if {!$success} {
        incr methods_tried
        log_msg "DEBUG" "  Trying method 3: -return_string variant"
        
        # Try adding -return_string flag
        set modified_cmd [regsub {^(\w+)} $report_cmd {\1 -return_string}]
        
        if {[catch {
            set output [eval $modified_cmd]
            set fp [open $file_path w]
            puts $fp $output
            close $fp
            
            if {[file exists $file_path] && [file size $file_path] > 0} {
                set size [file size $file_path]
                log_msg "INFO" "  SUCCESS (Method 3): ${size} bytes"
                set success 1
            }
        } err]} {
            log_msg "DEBUG" "  Method 3 failed: $err"
        }
    }
    
    # Method 4: Using redirect -variable (P-2019 specific)
    if {!$success} {
        incr methods_tried
        log_msg "DEBUG" "  Trying method 4: redirect -variable"
        if {[catch {
            redirect -variable report_output [list eval $report_cmd]
            set fp [open $file_path w]
            puts $fp $report_output
            close $fp
            
            if {[file exists $file_path] && [file size $file_path] > 0} {
                set size [file size $file_path]
                log_msg "INFO" "  SUCCESS (Method 4): ${size} bytes"
                set success 1
            }
        } err]} {
            log_msg "DEBUG" "  Method 4 failed: $err"
        }
    }
    
    # Method 5: Direct command execution and capture (last resort)
    if {!$success} {
        incr methods_tried
        log_msg "DEBUG" "  Trying method 5: Direct execution"
        if {[catch {
            set fp [open $file_path w]
            fconfigure $fp -buffering full
            
            # Temporarily redirect stdout
            set old_stdout stdout
            set temp_channel [open $file_path w]
            
            if {[catch {eval $report_cmd} result]} {
                close $temp_channel
                log_msg "DEBUG" "  Method 5 command failed: $result"
            } else {
                close $temp_channel
                if {[file exists $file_path] && [file size $file_path] > 0} {
                    set size [file size $file_path]
                    log_msg "INFO" "  SUCCESS (Method 5): ${size} bytes"
                    set success 1
                }
            }
        } err]} {
            log_msg "DEBUG" "  Method 5 failed: $err"
        }
    }
    
    # Final verification
    if {$success} {
        log_msg "INFO" "  REPORT GENERATED: $description"
        return 1
    } else {
        log_msg "WARNING" "  FAILED TO GENERATE: $description (tried $methods_tried methods)"
        
        # Create placeholder file
        if {[catch {
            set fp [open $file_path w]
            puts $fp "Report generation failed"
            puts $fp "Command: $report_cmd"
            puts $fp "Timestamp: [clock format [clock seconds]]"
            puts $fp ""
            puts $fp "This is a placeholder file."
            puts $fp "The report command did not execute successfully."
            close $fp
        }]} {
            log_msg "ERROR" "  Cannot even create placeholder file!"
        }
        
        return 0
    }
}

##############################################################################
# Lint Report Generation (Comprehensive)
##############################################################################

proc generate_lint_reports {report_dir top_module} {
    log_msg "INFO" "========================================"
    log_msg "INFO" "LINT REPORT GENERATION"
    log_msg "INFO" "  Module: $top_module"
    log_msg "INFO" "  Directory: $report_dir"
    log_msg "INFO" "========================================"
    
    # Validate directory
    if {![file exists $report_dir]} {
        log_msg "ERROR" "Report directory does not exist: $report_dir"
        return 0
    }
    
    if {![file isdirectory $report_dir]} {
        log_msg "ERROR" "Path is not a directory: $report_dir"
        return 0
    }
    
    # Test write permission
    set test_file [file join $report_dir ".write_test"]
    if {[catch {
        set fp [open $test_file w]
        puts $fp "test"
        close $fp
        file delete $test_file
    } err]} {
        log_msg "ERROR" "Directory not writable: $err"
        return 0
    }
    
    log_msg "INFO" "Directory validation passed"
    
    set violation_count 0
    set reports_generated 0
    
    # Report 1: Policy Summary
    log_msg "INFO" "Report 1/6: Policy Summary"
    set summary_file [file join $report_dir "lint_summary.rpt"]
    if {[write_report_to_file "report_policy_summary" $summary_file "Policy Summary"]} {
        incr reports_generated
    }
    
    # Report 2: Detailed Violations
    log_msg "INFO" "Report 2/6: Detailed Violations"
    set violations_file [file join $report_dir "lint_violations.rpt"]
    if {[write_report_to_file "report_policy -verbose" $violations_file "Detailed Violations"]} {
        incr reports_generated
    }
    
    # Report 3: Policy Rules
    log_msg "INFO" "Report 3/6: Policy Rules"
    set rules_file [file join $report_dir "lint_rules.rpt"]
    if {[write_report_to_file "report_policy -rules" $rules_file "Policy Rules"]} {
        incr reports_generated
    }
    
    # Report 4: Waived Violations
    log_msg "INFO" "Report 4/6: Waived Violations"
    set waived_file [file join $report_dir "lint_waived.rpt"]
    if {[write_report_to_file "report_policy -waived" $waived_file "Waived Violations"]} {
        incr reports_generated
    }
    
    # Report 5: Statistics
    log_msg "INFO" "Report 5/6: Statistics"
    set stats_file [file join $report_dir "lint_statistics.rpt"]
    if {[write_report_to_file "report_policy -statistics" $stats_file "Statistics"]} {
        incr reports_generated
    }
    
    # Report 6: Basic Policy (fallback)
    log_msg "INFO" "Report 6/6: Basic Policy Report"
    set basic_file [file join $report_dir "lint_policy.rpt"]
    if {[write_report_to_file "report_policy" $basic_file "Basic Policy"]} {
        incr reports_generated
    }
    
    # Generate custom summary
    generate_custom_summary $report_dir $top_module "Lint"
    
    # Count violations
    if {[catch {
        set summary_data [get_violation_summary]
        array set summary_array $summary_data
        if {[info exists summary_array(total)]} {
            set violation_count $summary_array(total)
        }
    }]} {
        log_msg "WARNING" "Could not extract violation count"
    }
    
    log_msg "INFO" "========================================"
    log_msg "INFO" "LINT REPORT GENERATION COMPLETE"
    log_msg "INFO" "  Reports generated: $reports_generated/6"
    log_msg "INFO" "  Violations: $violation_count"
    log_msg "INFO" "========================================"
    
    return $violation_count
}

##############################################################################
# CDC Report Generation
##############################################################################

proc generate_cdc_reports {report_dir top_module} {
    log_msg "INFO" "========================================"
    log_msg "INFO" "CDC REPORT GENERATION"
    log_msg "INFO" "  Module: $top_module"
    log_msg "INFO" "========================================"
    
    set reports_generated 0
    
    # CDC Report 1: Summary
    log_msg "INFO" "CDC Report 1/5: Summary"
    set summary_file [file join $report_dir "cdc_summary.rpt"]
    if {[write_report_to_file "report_policy_summary" $summary_file "CDC Summary"]} {
        incr reports_generated
    }
    
    # CDC Report 2: Violations
    log_msg "INFO" "CDC Report 2/5: Violations"
    set violations_file [file join $report_dir "cdc_violations.rpt"]
    if {[write_report_to_file "report_policy -verbose" $violations_file "CDC Violations"]} {
        incr reports_generated
    }
    
    # CDC Report 3: Clock Domains
    log_msg "INFO" "CDC Report 3/5: Clock Domains"
    set clock_file [file join $report_dir "clock_domains.rpt"]
    if {[write_report_to_file "report_clock_domain" $clock_file "Clock Domains"]} {
        incr reports_generated
    }
    
    # CDC Report 4: Clock Interactions
    log_msg "INFO" "CDC Report 4/5: Clock Interactions"
    set interact_file [file join $report_dir "clock_interactions.rpt"]
    if {[write_report_to_file "report_clock_interaction" $interact_file "Clock Interactions"]} {
        incr reports_generated
    }
    
    # CDC Report 5: Basic Policy
    log_msg "INFO" "CDC Report 5/5: Basic Policy"
    set policy_file [file join $report_dir "cdc_policy.rpt"]
    if {[write_report_to_file "report_policy" $policy_file "CDC Policy"]} {
        incr reports_generated
    }
    
    generate_custom_summary $report_dir $top_module "CDC"
    
    log_msg "INFO" "CDC reports: $reports_generated/5 generated"
    return 0
}

##############################################################################
# RDC Report Generation
##############################################################################

proc generate_rdc_reports {report_dir top_module} {
    log_msg "INFO" "========================================"
    log_msg "INFO" "RDC REPORT GENERATION"
    log_msg "INFO" "  Module: $top_module"
    log_msg "INFO" "========================================"
    
    set reports_generated 0
    
    # RDC Report 1: Summary
    log_msg "INFO" "RDC Report 1/5: Summary"
    set summary_file [file join $report_dir "rdc_summary.rpt"]
    if {[write_report_to_file "report_policy_summary" $summary_file "RDC Summary"]} {
        incr reports_generated
    }
    
    # RDC Report 2: Violations
    log_msg "INFO" "RDC Report 2/5: Violations"
    set violations_file [file join $report_dir "rdc_violations.rpt"]
    if {[write_report_to_file "report_policy -verbose" $violations_file "RDC Violations"]} {
        incr reports_generated
    }
    
    # RDC Report 3: Reset Domains
    log_msg "INFO" "RDC Report 3/5: Reset Domains"
    set reset_file [file join $report_dir "reset_domains.rpt"]
    if {[write_report_to_file "report_reset_domain" $reset_file "Reset Domains"]} {
        incr reports_generated
    }
    
    # RDC Report 4: Reset Interactions
    log_msg "INFO" "RDC Report 4/5: Reset Interactions"
    set interact_file [file join $report_dir "reset_interactions.rpt"]
    if {[write_report_to_file "report_reset_interaction" $interact_file "Reset Interactions"]} {
        incr reports_generated
    }
    
    # RDC Report 5: Basic Policy
    log_msg "INFO" "RDC Report 5/5: Basic Policy"
    set policy_file [file join $report_dir "rdc_policy.rpt"]
    if {[write_report_to_file "report_policy" $policy_file "RDC Policy"]} {
        incr reports_generated
    }
    
    generate_custom_summary $report_dir $top_module "RDC"
    
    log_msg "INFO" "RDC reports: $reports_generated/5 generated"
    return 0
}

##############################################################################
# Custom Summary Generation
##############################################################################

proc generate_custom_summary {report_dir top_module analysis_type} {
    set summary_file [file join $report_dir "ANALYSIS_SUMMARY.txt"]
    
    if {[catch {
        set fp [open $summary_file w]
        
        puts $fp "========================================="
        puts $fp "$analysis_type Analysis Summary"
        puts $fp "========================================="
        puts $fp "Module:    $top_module"
        puts $fp "Generated: [clock format [clock seconds]]"
        puts $fp "Directory: $report_dir"
        puts $fp ""
        
        # List all generated files
        puts $fp "Generated Report Files:"
        puts $fp "-----------------------------------------"
        
        set report_files [lsort [glob -nocomplain [file join $report_dir "*.rpt"]]]
        if {[llength $report_files] > 0} {
            foreach rpt $report_files {
                set name [file tail $rpt]
                set size [file size $rpt]
                puts $fp [format "  %-30s %10d bytes" $name $size]
            }
            puts $fp ""
            puts $fp "Total reports: [llength $report_files]"
        } else {
            puts $fp "  WARNING: No report files found!"
        }
        
        puts $fp ""
        puts $fp "========================================="
        
        close $fp
        log_msg "INFO" "Custom summary created: ANALYSIS_SUMMARY.txt"
    } err]} {
        log_msg "WARNING" "Failed to create custom summary: $err"
    }
}

##############################################################################
# Lint Goal Execution
##############################################################################

proc run_lint_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG REPORT_ONLY
    
    log_msg "INFO" "========================================="
    log_msg "INFO" "LINT ANALYSIS START"
    log_msg "INFO" "  Build: $BUILD_TAG"
    log_msg "INFO" "  Modules: $TOP_MODULES"
    log_msg "INFO" "  Report Only: $REPORT_ONLY"
    log_msg "INFO" "========================================="
    
    set report_dir [ensure_dir [file join $RESULTS_DIR "lint" "lint_$TIMESTAMP"]]
    
    if {$report_dir eq ""} {
        log_msg "ERROR" "Failed to create report directory"
        return 1
    }
    
    set total_violations 0
    set modules_processed 0
    set modules_failed 0
    
    foreach top $TOP_MODULES {
        log_msg "INFO" "========================================="
        log_msg "INFO" "Processing Module: $top"
        log_msg "INFO" "========================================="
        
        incr modules_processed
        start_timer "lint_$top"
        
        set module_failed 0
        
        if {!$REPORT_ONLY} {
            # Step 1: Clear goal
            log_msg "INFO" "Step 1/5: Clearing current goal"
            if {[catch {current_goal none} err]} {
                log_msg "WARNING" "Clear goal warning: $err"
            }
            
            # Step 2: Set top
            log_msg "INFO" "Step 2/5: Setting top module: $top"
            if {[catch {set_option top $top} err]} {
                log_msg "ERROR" "Failed to set top: $err"
                incr modules_failed
                set module_failed 1
            }
            
            # Step 3: Set goal
            if {!$module_failed} {
                log_msg "INFO" "Step 3/5: Setting lint goal"
                if {[catch {current_goal lint/lint_rtl} err]} {
                    log_msg "ERROR" "Failed to set goal: $err"
                    incr modules_failed
                    set module_failed 1
                }
            }
            
            # Step 4: Compile
            if {!$module_failed} {
                log_msg "INFO" "Step 4/5: Compiling design"
                if {[catch {compile_design} err]} {
                    log_msg "ERROR" "Compilation failed: $err"
                    incr modules_failed
                    set module_failed 1
                }
            }
            
            # Step 5: Run analysis
            if {!$module_failed} {
                log_msg "INFO" "Step 5/5: Running lint analysis"
                if {[catch {run_goal} err]} {
                    log_msg "ERROR" "Analysis failed: $err"
                    incr modules_failed
                    set module_failed 1
                }
            }
        }
        
        set elapsed [stop_timer "lint_$top"]
        
        # Generate reports (always, even if analysis failed)
        if {!$module_failed || $REPORT_ONLY} {
            log_msg "INFO" "Generating reports for $top"
            set top_report_dir [ensure_dir [file join $report_dir $top]]
            set violations [generate_lint_reports $top_report_dir $top]
            set total_violations [expr {$total_violations + $violations}]
            log_msg "INFO" "Module $top: $violations violations"
        } else {
            log_msg "WARNING" "Skipping report generation for failed module: $top"
        }
    }
    
    log_msg "INFO" "========================================="
    log_msg "INFO" "LINT ANALYSIS COMPLETE"
    log_msg "INFO" "  Modules processed: $modules_processed"
    log_msg "INFO" "  Modules failed: $modules_failed"
    log_msg "INFO" "  Total violations: $total_violations"
    log_msg "INFO" "========================================="
    
    generate_summary_report $report_dir "Lint Analysis" $BUILD_TAG $modules_processed $modules_failed $total_violations
    
    if {$modules_failed > 0 && !$REPORT_ONLY} {
        return 1
    }
    
    return 0
}

##############################################################################
# CDC Goal Execution
##############################################################################

proc run_cdc_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG REPORT_ONLY
    
    log_msg "INFO" "========================================="
    log_msg "INFO" "CDC ANALYSIS START"
    log_msg "INFO" "========================================="
    
    set report_dir [ensure_dir [file join $RESULTS_DIR "cdc" "cdc_$TIMESTAMP"]]
    set modules_failed 0
    
    foreach top $TOP_MODULES {
        log_msg "INFO" "CDC Analysis: $top"
        start_timer "cdc_$top"
        
        set module_failed 0
        
        if {!$REPORT_ONLY} {
            if {[catch {
                current_goal none
                set_option top $top
                current_goal cdc/cdc_setup_check
                compile_design
                run_goal
            } err]} {
                log_msg "ERROR" "CDC failed for $top: $err"
                incr modules_failed
                set module_failed 1
            }
        }
        
        stop_timer "cdc_$top"
        
        if {!$module_failed || $REPORT_ONLY} {
            set top_report_dir [ensure_dir [file join $report_dir $top]]
            generate_cdc_reports $top_report_dir $top
        }
    }
    
    generate_summary_report $report_dir "CDC Analysis" $BUILD_TAG [llength $TOP_MODULES] $modules_failed 0
    
    return [expr {$modules_failed > 0 ? 1 : 0}]
}

##############################################################################
# RDC Goal Execution
##############################################################################

proc run_rdc_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG REPORT_ONLY
    
    log_msg "INFO" "========================================="
    log_msg "INFO" "RDC ANALYSIS START"
    log_msg "INFO" "========================================="
    
    set report_dir [ensure_dir [file join $RESULTS_DIR "rdc" "rdc_$TIMESTAMP"]]
    set modules_failed 0
    
    foreach top $TOP_MODULES {
        log_msg "INFO" "RDC Analysis: $top"
        start_timer "rdc_$top"
        
        set module_failed 0
        
        if {!$REPORT_ONLY} {
            if {[catch {
                current_goal none
                set_option top $top
                current_goal rdc/rdc_setup_check
                compile_design
                run_goal
            } err]} {
                log_msg "ERROR" "RDC failed for $top: $err"
                incr modules_failed
                set module_failed 1
            }
        }
        
        stop_timer "rdc_$top"
        
        if {!$module_failed || $REPORT_ONLY} {
            set top_report_dir [ensure_dir [file join $report_dir $top]]
            generate_rdc_reports $top_report_dir $top
        }
    }
    
    generate_summary_report $report_dir "RDC Analysis" $BUILD_TAG [llength $TOP_MODULES] $modules_failed 0
    
    return [expr {$modules_failed > 0 ? 1 : 0}]
}

##############################################################################
# Master Summary Report
##############################################################################

proc generate_summary_report {report_dir analysis_type build_tag modules_total modules_failed violations} {
    set summary_file [file join $report_dir "00_MASTER_SUMMARY.txt"]
    
    log_msg "INFO" "Generating master summary: $summary_file"
    
    if {[catch {
        set fp [open $summary_file w]
        
        puts $fp "================================================================="
        puts $fp " $analysis_type - Master Summary Report"
        puts $fp "================================================================="
        puts $fp ""
        puts $fp "Analysis Information:"
        puts $fp "  Type:               $analysis_type"
        puts $fp "  Build Tag:          $build_tag"
        puts $fp "  Timestamp:          [clock format [clock seconds]]"
        puts $fp "  Report Directory:   $report_dir"
        puts $fp ""
        puts $fp "Analysis Statistics:"
        puts $fp "  Modules processed:  $modules_total"
        puts $fp "  Modules failed:     $modules_failed"
        puts $fp "  Modules succeeded:  [expr {$modules_total - $modules_failed}]"
        
        if {$violations > 0} {
            puts $fp "  Total violations:   $violations"
        }
        
        puts $fp ""
        puts $fp "Generated Module Reports:"
        puts $fp "-----------------------------------------------------------------"
        
        # List all module directories
        set module_dirs [glob -nocomplain -type d [file join $report_dir "*"]]
        if {[llength $module_dirs] > 0} {
            foreach mod_dir [lsort $module_dirs] {
                set mod_name [file tail $mod_dir]
                if {$mod_name ne "." && $mod_name ne ".."} {
                    puts $fp ""
                    puts $fp "Module: $mod_name"
                    
                    set report_files [glob -nocomplain [file join $mod_dir "*.rpt"]]
                    if {[llength $report_files] > 0} {
                        foreach rpt [lsort $report_files] {
                            set name [file tail $rpt]
                            set size [file size $rpt]
                            puts $fp [format "  %-35s %10d bytes" $name $size]
                        }
                    } else {
                        puts $fp "  No report files generated"
                    }
                }
            }
        } else {
            puts $fp "  No module directories found"
        }
        
        puts $fp ""
        puts $fp "================================================================="
        puts $fp " End of Summary"
        puts $fp "================================================================="
        
        close $fp
        log_msg "INFO" "Master summary created successfully"
        
    } err]} {
        log_msg "ERROR" "Failed to create master summary: $err"
    }
    
    # Also generate HTML
    generate_html_report $report_dir $analysis_type
}

##############################################################################
# Initialization
##############################################################################

log_msg "INFO" "run_goals.tcl v3.0 loaded (P-2019 production ready)"
load_goal_config
