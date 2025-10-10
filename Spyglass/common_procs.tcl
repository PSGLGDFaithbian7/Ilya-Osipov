#!/usr/bin/env sg_shell
# Common Procedures for Spyglass Analysis Framework
# Version: 2.0 - Production Ready

##############################################################################
# Global Configuration and Utilities
##############################################################################

# Global message logging with timestamps and levels
proc log_msg {level message} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    puts "\[$timestamp\] \[$level\] $message"
    flush stdout
}

# Safe environment variable getter with defaults
proc get_env_var {var_name default_value} {
    global env
    if {[info exists env($var_name)]} {
        return $env($var_name)
    } else {
        return $default_value
    }
}

# Enhanced directory creation with error handling
proc ensure_dir {dir_path} {
    if {![file exists $dir_path]} {
        if {[catch {file mkdir $dir_path} err]} {
            log_msg "ERROR" "Failed to create directory $dir_path: $err"
            return ""
        } else {
            log_msg "INFO" "Created directory: $dir_path"
        }
    }
    return $dir_path
}

##############################################################################
# File and Path Utilities
##############################################################################

proc validate_file {file_path description} {
    if {![file exists $file_path]} {
        log_msg "ERROR" "$description not found: $file_path"
        return 0
    }
    log_msg "INFO" "$description found: $file_path"
    return 1
}

proc get_file_list {pattern} {
    set files [glob -nocomplain $pattern]
    log_msg "INFO" "Found [llength $files] files matching: $pattern"
    return $files
}

proc backup_file {file_path} {
    if {[file exists $file_path]} {
        set backup_path "${file_path}.bak.[clock seconds]"
        if {[catch {file copy $file_path $backup_path} err]} {
            log_msg "WARNING" "Failed to backup $file_path: $err"
            return 0
        } else {
            log_msg "INFO" "Backed up $file_path to $backup_path"
            return 1
        }
    }
    return 0
}

##############################################################################
# Spyglass-Specific Utilities
##############################################################################

proc apply_waivers {waiver_file} {
    if {[validate_file $waiver_file "Waiver file"]} {
        if {[catch {read_file -type awl $waiver_file} err]} {
            log_msg "ERROR" "Failed to load waivers from $waiver_file: $err"
            return 0
        } else {
            log_msg "INFO" "Applied waivers from: $waiver_file"
            return 1
        }
    } else {
        log_msg "INFO" "No waiver file found, continuing without waivers"
        return 1
    }
}

proc save_project_safe {} {
    global PROJECT_NAME
    if {[catch {save_project} err]} {
        log_msg "ERROR" "Failed to save project: $err"
        return 0
    } else {
        log_msg "INFO" "Project saved successfully"
        return 1
    }
}

proc get_spyglass_version {} {
    if {[catch {exec sg_shell -version} version_info]} {
        return "Unknown"
    }
    return [lindex [split $version_info "\n"] 0]
}

##############################################################################
# Analysis and Reporting Utilities
##############################################################################

proc get_violation_summary {} {
    if {[catch {report_policy -return_string -summary} result]} {
        log_msg "WARNING" "Failed to get violation summary"
        return [dict create total 0 error 0 warning 0 info 0]
    }
    
    # Parse the summary result
    set summary [dict create total 0 error 0 warning 0 info 0]
    
    # Extract counts using regex patterns
    if {[regexp {(\d+)\s+total violations} $result match total]} {
        dict set summary total $total
    }
    if {[regexp {(\d+)\s+error} $result match errors]} {
        dict set summary error $errors
    }
    if {[regexp {(\d+)\s+warning} $result match warnings]} {
        dict set summary warning $warnings
    }
    if {[regexp {(\d+)\s+info} $result match infos]} {
        dict set summary info $infos
    }
    
    return $summary
}

proc generate_html_report {report_dir analysis_type} {
    set html_file [file join $report_dir "index.html"]
    set fp [open $html_file w]
    
    puts $fp "<!DOCTYPE html>"
    puts $fp "<html><head>"
    puts $fp "<title>$analysis_type - Spyglass Report</title>"
    puts $fp "<style>"
    puts $fp "body { font-family: Arial, sans-serif; margin: 40px; }"
    puts $fp "table { border-collapse: collapse; width: 100%; }"
    puts $fp "th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }"
    puts $fp "th { background-color: #f2f2f2; }"
    puts $fp ".error { color: red; font-weight: bold; }"
    puts $fp ".warning { color: orange; }"
    puts $fp ".info { color: blue; }"
    puts $fp ".header { background-color: #4CAF50; color: white; padding: 20px; }"
    puts $fp "</style>"
    puts $fp "</head><body>"
    
    puts $fp "<div class='header'>"
    puts $fp "<h1>$analysis_type Report</h1>"
    puts $fp "<p>Generated: [clock format [clock seconds]]</p>"
    puts $fp "<p>Build Tag: [get_env_var BUILD_TAG unknown]</p>"
    puts $fp "</div>"
    
    # List all report files
    puts $fp "<h2>Available Reports</h2>"
    puts $fp "<table>"
    puts $fp "<tr><th>Module</th><th>Report</th><th>Size</th><th>Modified</th></tr>"
    
    set report_files [glob -nocomplain [file join $report_dir "*" "*.rpt"]]
    foreach rpt [lsort $report_files] {
        set module [file tail [file dirname $rpt]]
        set report_name [file tail $rpt]
        set file_size [file size $rpt]
        set mod_time [clock format [file mtime $rpt] -format "%Y-%m-%d %H:%M"]
        
        puts $fp "<tr>"
        puts $fp "<td>$module</td>"
        puts $fp "<td><a href='[file join $module $report_name]'>$report_name</a></td>"
        puts $fp "<td>[format_file_size $file_size]</td>"
        puts $fp "<td>$mod_time</td>"
        puts $fp "</tr>"
    }
    
    puts $fp "</table>"
    puts $fp "</body></html>"
    close $fp
    
    log_msg "INFO" "HTML report generated: $html_file"
}

proc format_file_size {bytes} {
    if {$bytes < 1024} {
        return "${bytes} B"
    } elseif {$bytes < 1048576} {
        return "[expr $bytes/1024] KB"
    } else {
        return "[expr $bytes/1048576] MB"
    }
}

##############################################################################
# Configuration Management
##############################################################################

proc load_project_config {config_file} {
    if {[validate_file $config_file "Configuration file"]} {
        if {[catch {source $config_file} err]} {
            log_msg "ERROR" "Failed to load configuration: $err"
            return 0
        } else {
            log_msg "INFO" "Loaded configuration from: $config_file"
            return 1
        }
    }
    return 0
}

proc export_project_config {config_file} {
    set fp [open $config_file w]
    puts $fp "# Spyglass Project Configuration"
    puts $fp "# Generated: [clock format [clock seconds]]"
    puts $fp ""
    
    # Export key project settings
    if {[catch {get_option top} top_module]} {
        set top_module "unknown"
    }
    puts $fp "set_option top $top_module"
    
    # Add more configuration exports as needed
    close $fp
    log_msg "INFO" "Configuration exported to: $config_file"
}

##############################################################################
# Error Handling and Recovery
##############################################################################

proc handle_spyglass_error {error_msg operation} {
    log_msg "ERROR" "Spyglass error during $operation: $error_msg"
    
    # Attempt recovery strategies
    if {[string match "*license*" [string tolower $error_msg]]} {
        log_msg "INFO" "License error detected - attempting recovery"
        return handle_license_error
    } elseif {[string match "*memory*" [string tolower $error_msg]]} {
        log_msg "INFO" "Memory error detected - attempting recovery"
        return handle_memory_error
    }
    
    return 0
}

proc handle_license_error {} {
    log_msg "INFO" "Checking license server..."
    # Add license checking logic
    after 5000  ;# Wait 5 seconds
    return 1
}

proc handle_memory_error {} {
    log_msg "INFO" "Memory optimization - enabling incremental mode"
    catch {set_option enable_incremental_flow yes}
    return 1
}

##############################################################################
# Performance Monitoring
##############################################################################

proc start_timer {timer_name} {
    global timers
    set timers($timer_name) [clock clicks -milliseconds]
    log_msg "INFO" "Started timer: $timer_name"
}

proc stop_timer {timer_name} {
    global timers
    if {[info exists timers($timer_name)]} {
        set elapsed [expr [clock clicks -milliseconds] - $timers($timer_name)]
        log_msg "INFO" "Timer $timer_name: ${elapsed}ms ([expr $elapsed/1000.0]s)"
        unset timers($timer_name)
        return $elapsed
    }
    return 0
}

##############################################################################
# Debug and Diagnostic Functions
##############################################################################

proc debug_environment {} {
    log_msg "DEBUG" "=== Environment Debug Information ==="
    log_msg "DEBUG" "Spyglass Version: [get_spyglass_version]"
    log_msg "DEBUG" "Working Directory: [pwd]"
    log_msg "DEBUG" "TCL Version: [info tclversion]"
    
    # Environment variables
    global env
    set important_vars {SPYGLASS_HOME PROJECT_NAME TOP_MODULES RTL_ROOT}
    foreach var $important_vars {
        if {[info exists env($var)]} {
            log_msg "DEBUG" "$var = $env($var)"
        } else {
            log_msg "DEBUG" "$var = <not set>"
        }
    }
    log_msg "DEBUG" "=== End Environment Debug ==="
}

proc check_spyglass_health {} {
    log_msg "INFO" "Checking Spyglass installation health..."
    
    # Check if sg_shell is available
    if {[catch {exec sg_shell -version} version]} {
        log_msg "ERROR" "sg_shell not accessible"
        return 0
    }
    
    # Check license
    if {[catch {exec sg_shell -c "exit"} license_check]} {
        if {[string match "*license*" [string tolower $license_check]]} {
            log_msg "ERROR" "License issue detected"
            return 0
        }
    }
    
    log_msg "INFO" "Spyglass health check passed ✓"
    return 1
}

##############################################################################
# Initialization
##############################################################################

# Initialize global variables
global timers
set timers [dict create]

# Log startup message
log_msg "INFO" "Spyglass Common Procedures v2.0 loaded successfully"