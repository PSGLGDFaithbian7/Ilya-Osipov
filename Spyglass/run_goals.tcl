#!/usr/bin/env sg_shell
# Run Goals Script - Standalone TCL File

set script_dir [file dirname [info script]]
source [file join $script_dir "common_procs.tcl"]

##############################################################################
# Configuration
##############################################################################

proc load_goal_config {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG
    
    set RESULTS_DIR [get_env_var "RESULTS_DIR" "./results"]
    set TIMESTAMP   [get_env_var "TIMESTAMP" [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]]
    set top_str     [get_env_var "TOP_MODULES" "top_module"]
    set TOP_MODULES [split $top_str]
    set BUILD_TAG   [get_env_var "BUILD_TAG" "unknown"]
}

##############################################################################
# Lint Goal
##############################################################################

proc run_lint_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG
    
    log_msg "INFO" "Starting lint analysis (Build: $BUILD_TAG)"
    
    set report_dir [ensure_dir [file join $RESULTS_DIR "lint" "lint_$TIMESTAMP"]]
    
    # Set lint goal
    if {[catch {current_goal lint/lint_rtl} err]} {
        log_msg "ERROR" "Failed to set lint goal: $err"
        return -1
    }
    
    # Process each top module
    set total_violations 0
    foreach top $TOP_MODULES {
        log_msg "INFO" "Processing top module: $top"
        
        start_timer "lint_$top"
        
        # Compile and run
        if {[catch {
            set_option top $top
            compile_design
            run_goal
        } err]} {
            log_msg "ERROR" "Analysis failed for $top: $err"
            return -1
        }
        
        stop_timer "lint_$top"
        
        # Generate reports
        set top_report_dir [ensure_dir [file join $report_dir $top]]
        set violations [generate_lint_reports $top_report_dir $top]
        set total_violations [expr {$total_violations + $violations}]
    }
    
    log_msg "INFO" "Lint completed with $total_violations total violations"
    
    # Generate summary
    generate_summary_report $report_dir "Lint Analysis" $BUILD_TAG
    
    return 0
}

##############################################################################
# CDC Goal
##############################################################################

proc run_cdc_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG
    
    log_msg "INFO" "Starting CDC analysis"
    
    set report_dir [ensure_dir [file join $RESULTS_DIR "cdc" "cdc_$TIMESTAMP"]]
    
    if {[catch {current_goal cdc/cdc_setup_check} err]} {
        log_msg "ERROR" "Failed to set CDC goal: $err"
        return -1
    }
    
    foreach top $TOP_MODULES {
        log_msg "INFO" "CDC analysis for: $top"
        
        if {[catch {
            set_option top $top
            compile_design
            run_goal
        } err]} {
            log_msg "ERROR" "CDC failed for $top: $err"
            return -1
        }
        
        set top_report_dir [ensure_dir [file join $report_dir $top]]
        generate_cdc_reports $top_report_dir $top
    }
    
    generate_summary_report $report_dir "CDC Analysis" $BUILD_TAG
    return 0
}

##############################################################################
# RDC Goal
##############################################################################

proc run_rdc_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG
    
    log_msg "INFO" "Starting RDC analysis"
    
    set report_dir [ensure_dir [file join $RESULTS_DIR "rdc" "rdc_$TIMESTAMP"]]
    
    if {[catch {current_goal rdc/rdc_setup_check} err]} {
        log_msg "ERROR" "Failed to set RDC goal: $err"
        return -1
    }
    
    foreach top $TOP_MODULES {
        log_msg "INFO" "RDC analysis for: $top"
        
        if {[catch {
            set_option top $top
            compile_design
            run_goal
        } err]} {
            log_msg "ERROR" "RDC failed for $top: $err"
            return -1
        }
        
        set top_report_dir [ensure_dir [file join $report_dir $top]]
        generate_rdc_reports $top_report_dir $top
    }
    
    generate_summary_report $report_dir "RDC Analysis" $BUILD_TAG
    return 0
}

##############################################################################
# Report Generation
##############################################################################

proc generate_lint_reports {report_dir top_module} {
    log_msg "INFO" "Generating lint reports for $top_module"
    
    set violation_count 0
    
    # Generate reports with error handling
    if {[catch {
        report_policy_summary > [file join $report_dir "lint_summary.rpt"]
    } err]} {
        log_msg "WARNING" "Failed to generate summary: $err"
    }
    
    catch {report_policy -verbose > [file join $report_dir "lint_violations.rpt"]}
    catch {report_policy -rules > [file join $report_dir "lint_rules.rpt"]}
    catch {report_policy -waived > [file join $report_dir "lint_waived.rpt"]}
    
    # Count violations
    if {[catch {
        set summary [get_violation_summary]
        set violation_count [dict get $summary total]
    }]} {
        set violation_count 0
    }
    
    log_msg "INFO" "Generated reports ($violation_count violations)"
    return $violation_count
}

proc generate_cdc_reports {report_dir top_module} {
    log_msg "INFO" "Generating CDC reports for $top_module"
    
    catch {report_policy_summary > [file join $report_dir "cdc_summary.rpt"]}
    catch {report_policy -verbose > [file join $report_dir "cdc_violations.rpt"]}
    catch {report_clock_domain > [file join $report_dir "clock_domains.rpt"]}
}

proc generate_rdc_reports {report_dir top_module} {
    log_msg "INFO" "Generating RDC reports for $top_module"
    
    catch {report_policy_summary > [file join $report_dir "rdc_summary.rpt"]}
    catch {report_policy -verbose > [file join $report_dir "rdc_violations.rpt"]}
    catch {report_reset_domain > [file join $report_dir "reset_domains.rpt"]}
}

proc generate_summary_report {report_dir analysis_type build_tag} {
    set summary_file [file join $report_dir "00_SUMMARY.txt"]
    set fp [open $summary_file w]
    
    puts $fp "$analysis_type Summary"
    puts $fp "======================================="
    puts $fp "Generated: [clock format [clock seconds]]"
    puts $fp "Build Tag: $build_tag"
    puts $fp ""
    
    puts $fp "Generated Reports:"
    set report_files [glob -nocomplain [file join $report_dir "*" "*.rpt"]]
    foreach rpt [lsort $report_files] {
        set rel_path [file join [file tail [file dirname $rpt]] [file tail $rpt]]
        puts $fp "  $rel_path"
    }
    
    close $fp
    
    log_msg "INFO" "Summary report generated: $summary_file"
    
    # Generate HTML index
    generate_html_report $report_dir $analysis_type
}

##############################################################################
# Initialize
##############################################################################

load_goal_config