#!/usr/bin/env sg_shell
# Common Procedures for Spyglass Analysis Framework
# Version: 2.1 - P-2019 Compatible

##############################################################################
# Global Configuration and Utilities
##############################################################################

# Global message logging with timestamps and levels
proc log_msg {level message} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    puts "```math
$timestamp``` ```math
$level``` $message"
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

proc get_violation_summary {} {
    if {[catch {report_policy -return_string -summary} result]} {
        log_msg "WARNING" "Failed to get violation summary"
        # 返回数组而不是字典（P-2019兼容）
        return [list total 0 error 0 warning 0 info 0]
    }
    
    # 解析摘要结果
    array set summary {total 0 error 0 warning 0 info 0}
    
    # 提取计数
    if {[regexp {(\d+)\s+total violations} $result match total]} {
        set summary(total) $total
    }
    if {[regexp {(\d+)\s+error} $result match errors]} {
        set summary(error) $errors
    }
    if {[regexp {(\d+)\s+warning} $result match warnings]} {
        set summary(warning) $warnings
    }
    if {[regexp {(\d+)\s+info} $result match infos]} {
        set summary(info) $infos
    }
    
    return [array get summary]
}

##############################################################################
# Performance Monitoring - Fixed Array Version
##############################################################################

# 初始化全局计时器数组
global timers
array set timers {}

proc start_timer {timer_name} {
    global timers
    set timers($timer_name) [clock clicks -milliseconds]
    log_msg "INFO" "Started timer: $timer_name"
}

proc stop_timer {timer_name} {
    global timers
    if {[info exists timers($timer_name)]} {
        set elapsed [expr {[clock clicks -milliseconds] - $timers($timer_name)}]
        set seconds [format "%.2f" [expr {$elapsed/1000.0}]]
        log_msg "INFO" "Timer $timer_name: ${elapsed}ms (${seconds}s)"
        unset timers($timer_name)
        return $elapsed
    }
    log_msg "WARNING" "Timer $timer_name was not started"
    return 0
}

##############################################################################
# HTML Report Generation
##############################################################################

proc generate_html_report {report_dir analysis_type} {
    set html_file [file join $report_dir "index.html"]
    
    if {[catch {
        set fp [open $html_file w]
        
        puts $fp "<!DOCTYPE html>"
        puts $fp "<html><head>"
        puts $fp "<title>$analysis_type - Spyglass Report</title>"
        puts $fp "<style>"
        puts $fp "body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }"
        puts $fp "h1 { color: #333; border-bottom: 2px solid #4CAF50; padding-bottom: 10px; }"
        puts $fp "table { border-collapse: collapse; width: 100%; background-color: white; margin-top: 20px; }"
        puts $fp "th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }"
        puts $fp "th { background-color: #4CAF50; color: white; }"
        puts $fp "tr:hover { background-color: #f1f1f1; }"
        puts $fp ".info { color: #666; margin: 10px 0; }"
        puts $fp "</style>"
        puts $fp "</head><body>"
        
        puts $fp "<h1>$analysis_type Report</h1>"
        puts $fp "<p class='info'>Generated: [clock format [clock seconds]]</p>"
        puts $fp "<p class='info'>Build Tag: [get_env_var BUILD_TAG unknown]</p>"
        
        # 列出所有报告文件
        puts $fp "<h2>Available Reports</h2>"
        puts $fp "<table>"
        puts $fp "<tr><th>Module</th><th>Report</th><th>Size</th></tr>"
        
        set report_files [glob -nocomplain [file join $report_dir "*" "*.rpt"]]
        if {[llength $report_files] > 0} {
            foreach rpt [lsort $report_files] {
                set module [file tail [file dirname $rpt]]
                set report_name [file tail $rpt]
                set file_size [file size $rpt]
                
                puts $fp "<tr>"
                puts $fp "<td>$module</td>"
                puts $fp "<td><a href='[file join $module $report_name]'>$report_name</a></td>"
                puts $fp "<td>[format_file_size $file_size]</td>"
                puts $fp "</tr>"
            }
        } else {
            puts $fp "<tr><td colspan='3'>No report files found</td></tr>"
        }
        
        puts $fp "</table>"
        puts $fp "</body></html>"
        close $fp
        
        log_msg "INFO" "HTML report generated: $html_file"
    } err]} {
        log_msg "ERROR" "Failed to generate HTML report: $err"
    }
}

proc format_file_size {bytes} {
    if {$bytes < 1024} {
        return "${bytes} B"
    } elseif {$bytes < 1048576} {
        return "[expr {$bytes/1024}] KB"
    } else {
        return "[expr {$bytes/1048576}] MB"
    }
}

##############################################################################
# Initialization
##############################################################################

# Log startup message
log_msg "INFO" "Spyglass Common Procedures v2.1 loaded (P-2019 compatible)"
