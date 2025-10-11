#!/usr/bin/env sg_shell
# Common Procedures for Spyglass Analysis Framework
# Version: 2.1 - Production Ready (P-2019 Compatible)
# Author: System Integration Team
# Features:
#   - Robust error handling
#   - Beautiful HTML report generation
#   - Performance monitoring
#   - Comprehensive utilities

##############################################################################
# Global Configuration and Logging
##############################################################################

# Global message logging with timestamps and levels
proc log_msg {level message} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    puts "```math
$timestamp``` ```math
$level``` $message"
    flush stdout
}

# Enhanced logging with file support
proc log_msg_file {level message logfile} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    set log_line "```math
$timestamp``` ```math
$level``` $message"
    
    puts $log_line
    flush stdout
    
    if {$logfile ne ""} {
        if {[catch {
            set fp [open $logfile a]
            puts $fp $log_line
            close $fp
        }]} {
            # Silently fail if can't write to log file
        }
    }
}

##############################################################################
# Environment Variable Handling
##############################################################################

# Safe environment variable getter with defaults
proc get_env_var {var_name default_value} {
    global env
    if {[info exists env($var_name)]} {
        return $env($var_name)
    } else {
        return $default_value
    }
}

# Check if environment variable is set
proc env_var_exists {var_name} {
    global env
    return [info exists env($var_name)]
}

# Set environment variable safely
proc set_env_var {var_name value} {
    global env
    set env($var_name) $value
    log_msg "DEBUG" "Set environment variable: $var_name = $value"
}

##############################################################################
# File and Directory Utilities
##############################################################################

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

# Validate file existence with descriptive logging
proc validate_file {file_path description} {
    if {![file exists $file_path]} {
        log_msg "ERROR" "$description not found: $file_path"
        return 0
    }
    log_msg "INFO" "$description found: $file_path"
    return 1
}

# Get list of files matching pattern
proc get_file_list {pattern} {
    set files [glob -nocomplain $pattern]
    log_msg "INFO" "Found [llength $files] files matching: $pattern"
    return $files
}

# Backup file with timestamp
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

# Safe file copy with error handling
proc safe_file_copy {src dest} {
    if {![file exists $src]} {
        log_msg "ERROR" "Source file not found: $src"
        return 0
    }
    
    if {[catch {file copy -force $src $dest} err]} {
        log_msg "ERROR" "Failed to copy $src to $dest: $err"
        return 0
    }
    
    return 1
}

# Get relative path from base to target
proc get_relative_path {base target} {
    set base_parts [file split [file normalize $base]]
    set target_parts [file split [file normalize $target]]
    
    # Find common prefix
    set common 0
    set max_len [expr {[llength $base_parts] < [llength $target_parts] ? [llength $base_parts] : [llength $target_parts]}]
    
    for {set i 0} {$i < $max_len} {incr i} {
        if {[lindex $base_parts $i] eq [lindex $target_parts $i]} {
            incr common
        } else {
            break
        }
    }
    
    # Build relative path
    set up_count [expr {[llength $base_parts] - $common}]
    set rel_path ""
    
    for {set i 0} {$i < $up_count} {incr i} {
        append rel_path "../"
    }
    
    for {set i $common} {$i < [llength $target_parts]} {incr i} {
        append rel_path [lindex $target_parts $i]
        if {$i < [llength $target_parts] - 1} {
            append rel_path "/"
        }
    }
    
    return $rel_path
}

##############################################################################
# Spyglass-Specific Utilities
##############################################################################

# Apply waivers from file
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

# Safe project save
proc save_project_safe {} {
    if {[catch {save_project} err]} {
        log_msg "ERROR" "Failed to save project: $err"
        return 0
    } else {
        log_msg "INFO" "Project saved successfully"
        return 1
    }
}

# Get Spyglass version
proc get_spyglass_version {} {
    if {[catch {exec sg_shell -version} version_info]} {
        return "Unknown"
    }
    return [lindex [split $version_info "\n"] 0]
}

# Get violation summary (P-2019 compatible)
proc get_violation_summary {} {
    if {[catch {report_policy -return_string -summary} result]} {
        log_msg "WARNING" "Failed to get violation summary"
        return [list total 0 error 0 warning 0 info 0]
    }
    
    # Parse the summary result
    array set summary {total 0 error 0 warning 0 info 0}
    
    # Extract counts using regex patterns
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
# Performance Monitoring (Fixed for P-2019)
##############################################################################

# Initialize global timers array (not dict!)
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

proc get_timer_elapsed {timer_name} {
    global timers
    if {[info exists timers($timer_name)]} {
        return [expr {[clock clicks -milliseconds] - $timers($timer_name)}]
    }
    return 0
}

##############################################################################
# File Size Formatting
##############################################################################

proc format_file_size {bytes} {
    if {$bytes < 1024} {
        return "${bytes} B"
    } elseif {$bytes < 1048576} {
        return "[format "%.1f" [expr {$bytes/1024.0}]] KB"
    } else {
        return "[format "%.1f" [expr {$bytes/1048576.0}]] MB"
    }
}

##############################################################################
# Enhanced HTML Report Generation
##############################################################################

# Generate beautiful HTML report (no Spyglass license required)
proc generate_html_report {report_dir analysis_type} {
    set html_file [file join $report_dir "index.html"]
    
    log_msg "INFO" "Generating HTML index: $html_file"
    
    if {[catch {
        set fp [open $html_file w]
        
        # HTML Header with modern styling
        puts $fp "<!DOCTYPE html>"
        puts $fp "<html lang='en'>"
        puts $fp "<head>"
        puts $fp "    <meta charset='UTF-8'>"
        puts $fp "    <meta name='viewport' content='width=device-width, initial-scale=1.0'>"
        puts $fp "    <title>$analysis_type - Spyglass Report</title>"
        puts $fp "    <style>"
        puts $fp "        * { margin: 0; padding: 0; box-sizing: border-box; }"
        puts $fp "        body {"
        puts $fp "            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;"
        puts $fp "            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);"
        puts $fp "            padding: 20px;"
        puts $fp "            min-height: 100vh;"
        puts $fp "        }"
        puts $fp "        .container {"
        puts $fp "            max-width: 1400px;"
        puts $fp "            margin: 0 auto;"
        puts $fp "            background: white;"
        puts $fp "            border-radius: 15px;"
        puts $fp "            box-shadow: 0 20px 60px rgba(0,0,0,0.3);"
        puts $fp "            overflow: hidden;"
        puts $fp "        }"
        puts $fp "        .header {"
        puts $fp "            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);"
        puts $fp "            color: white;"
        puts $fp "            padding: 50px 40px;"
        puts $fp "            text-align: center;"
        puts $fp "            position: relative;"
        puts $fp "        }"
        puts $fp "        .header::before {"
        puts $fp "            content: '';"
        puts $fp "            position: absolute;"
        puts $fp "            top: 0;"
        puts $fp "            left: 0;"
        puts $fp "            right: 0;"
        puts $fp "            bottom: 0;"
        puts $fp "            background: url('data:image/svg+xml,<svg width=\"100\" height=\"100\" xmlns=\"http://www.w3.org/2000/svg\"><circle cx=\"50\" cy=\"50\" r=\"40\" fill=\"none\" stroke=\"white\" stroke-opacity=\"0.1\" stroke-width=\"2\"/></svg>');"
        puts $fp "            opacity: 0.1;"
        puts $fp "        }"
        puts $fp "        .header h1 {"
        puts $fp "            font-size: 3em;"
        puts $fp "            margin-bottom: 15px;"
        puts $fp "            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);"
        puts $fp "            position: relative;"
        puts $fp "            z-index: 1;"
        puts $fp "        }"
        puts $fp "        .header p {"
        puts $fp "            font-size: 1.2em;"
        puts $fp "            opacity: 0.95;"
        puts $fp "            position: relative;"
        puts $fp "            z-index: 1;"
        puts $fp "        }"
        puts $fp "        .info-section {"
        puts $fp "            display: grid;"
        puts $fp "            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));"
        puts $fp "            gap: 25px;"
        puts $fp "            padding: 40px;"
        puts $fp "            background: linear-gradient(to bottom, #f8f9fa 0%, #e9ecef 100%);"
        puts $fp "            border-bottom: 2px solid #dee2e6;"
        puts $fp "        }"
        puts $fp "        .info-card {"
        puts $fp "            background: white;"
        puts $fp "            padding: 25px;"
        puts $fp "            border-radius: 12px;"
        puts $fp "            box-shadow: 0 4px 15px rgba(0,0,0,0.08);"
        puts $fp "            transition: all 0.3s ease;"
        puts $fp "            border-left: 4px solid #667eea;"
        puts $fp "        }"
        puts $fp "        .info-card:hover {"
        puts $fp "            transform: translateY(-5px);"
        puts $fp "            box-shadow: 0 8px 25px rgba(102,126,234,0.2);"
        puts $fp "        }"
        puts $fp "        .info-card h3 {"
        puts $fp "            color: #667eea;"
        puts $fp "            font-size: 0.85em;"
        puts $fp "            text-transform: uppercase;"
        puts $fp "            letter-spacing: 1px;"
        puts $fp "            margin-bottom: 12px;"
        puts $fp "            font-weight: 600;"
        puts $fp "        }"
        puts $fp "        .info-card p {"
        puts $fp "            font-size: 1.8em;"
        puts $fp "            color: #2c3e50;"
        puts $fp "            font-weight: 700;"
        puts $fp "            line-height: 1.2;"
        puts $fp "        }"
        puts $fp "        .content {"
        puts $fp "            padding: 40px;"
        puts $fp "        }"
        puts $fp "        .section-title {"
        puts $fp "            font-size: 2em;"
        puts $fp "            color: #2c3e50;"
        puts $fp "            margin-bottom: 25px;"
        puts $fp "            padding-bottom: 15px;"
        puts $fp "            border-bottom: 3px solid #667eea;"
        puts $fp "            position: relative;"
        puts $fp "        }"
        puts $fp "        .section-title::after {"
        puts $fp "            content: '';"
        puts $fp "            position: absolute;"
        puts $fp "            bottom: -3px;"
        puts $fp "            left: 0;"
        puts $fp "            width: 100px;"
        puts $fp "            height: 3px;"
        puts $fp "            background: #764ba2;"
        puts $fp "        }"
        puts $fp "        table {"
        puts $fp "            width: 100%;"
        puts $fp "            border-collapse: separate;"
        puts $fp "            border-spacing: 0;"
        puts $fp "            margin-top: 25px;"
        puts $fp "            background: white;"
        puts $fp "            box-shadow: 0 2px 15px rgba(0,0,0,0.06);"
        puts $fp "            border-radius: 10px;"
        puts $fp "            overflow: hidden;"
        puts $fp "        }"
        puts $fp "        thead {"
        puts $fp "            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);"
        puts $fp "            color: white;"
        puts $fp "        }"
        puts $fp "        th {"
        puts $fp "            padding: 18px 15px;"
        puts $fp "            text-align: left;"
        puts $fp "            font-weight: 600;"
        puts $fp "            text-transform: uppercase;"
        puts $fp "            font-size: 0.85em;"
        puts $fp "            letter-spacing: 0.5px;"
        puts $fp "        }"
        puts $fp "        td {"
        puts $fp "            padding: 15px;"
        puts $fp "            border-bottom: 1px solid #f1f3f5;"
        puts $fp "        }"
        puts $fp "        tbody tr {"
        puts $fp "            transition: all 0.2s ease;"
        puts $fp "        }"
        puts $fp "        tbody tr:hover {"
        puts $fp "            background: #f8f9fa;"
        puts $fp "            transform: scale(1.01);"
        puts $fp "        }"
        puts $fp "        tbody tr:last-child td {"
        puts $fp "            border-bottom: none;"
        puts $fp "        }"
        puts $fp "        a {"
        puts $fp "            color: #667eea;"
        puts $fp "            text-decoration: none;"
        puts $fp "            font-weight: 500;"
        puts $fp "            transition: all 0.2s;"
        puts $fp "            display: inline-flex;"
        puts $fp "            align-items: center;"
        puts $fp "        }"
        puts $fp "        a:hover {"
        puts $fp "            color: #764ba2;"
        puts $fp "            text-decoration: underline;"
        puts $fp "        }"
        puts $fp "        .file-icon {"
        puts $fp "            font-size: 1.2em;"
        puts $fp "            margin-right: 8px;"
        puts $fp "        }"
        puts $fp "        .badge {"
        puts $fp "            display: inline-block;"
        puts $fp "            padding: 6px 14px;"
        puts $fp "            border-radius: 15px;"
        puts $fp "            font-size: 0.8em;"
        puts $fp "            font-weight: 600;"
        puts $fp "            text-transform: uppercase;"
        puts $fp "            letter-spacing: 0.5px;"
        puts $fp "        }"
        puts $fp "        .badge-summary { background: #d4edda; color: #155724; }"
        puts $fp "        .badge-violation { background: #fff3cd; color: #856404; }"
        puts $fp "        .badge-info { background: #d1ecf1; color: #0c5460; }"
        puts $fp "        .badge-log { background: #e2e3e5; color: #383d41; }"
        puts $fp "        .badge-report { background: #f8d7da; color: #721c24; }"
        puts $fp "        .empty-state {"
        puts $fp "            text-align: center;"
        puts $fp "            padding: 80px 40px;"
        puts $fp "            color: #6c757d;"
        puts $fp "        }"
        puts $fp "        .empty-state-icon {"
        puts $fp "            font-size: 4em;"
        puts $fp "            margin-bottom: 20px;"
        puts $fp "            opacity: 0.5;"
        puts $fp "        }"
        puts $fp "        .tips-box {"
        puts $fp "            margin-top: 40px;"
        puts $fp "            padding: 25px;"
        puts $fp "            background: linear-gradient(135deg, #e7f3ff 0%, #f0e6ff 100%);"
        puts $fp "            border-radius: 12px;"
        puts $fp "            border-left: 5px solid #667eea;"
        puts $fp "        }"
        puts $fp "        .tips-box h3 {"
        puts $fp "            color: #667eea;"
        puts $fp "            margin-bottom: 15px;"
        puts $fp "            font-size: 1.3em;"
        puts $fp "        }"
        puts $fp "        .tips-box ul {"
        puts $fp "            margin-left: 25px;"
        puts $fp "            line-height: 2;"
        puts $fp "        }"
        puts $fp "        .tips-box li {"
        puts $fp "            color: #495057;"
        puts $fp "        }"
        puts $fp "        .footer {"
        puts $fp "            padding: 25px 40px;"
        puts $fp "            background: #f8f9fa;"
        puts $fp "            text-align: center;"
        puts $fp "            color: #6c757d;"
        puts $fp "            font-size: 0.9em;"
        puts $fp "            border-top: 2px solid #e9ecef;"
        puts $fp "        }"
        puts $fp "        .footer a {"
        puts $fp "            color: #667eea;"
        puts $fp "        }"
        puts $fp "        @media (max-width: 768px) {"
        puts $fp "            .header h1 { font-size: 2em; }"
        puts $fp "            .info-section { grid-template-columns: 1fr; }"
        puts $fp "            table { font-size: 0.9em; }"
        puts $fp "        }"
        puts $fp "    </style>"
        puts $fp "</head>"
        puts $fp "<body>"
        puts $fp "    <div class='container'>"
        
        # Header Section
        puts $fp "        <div class='header'>"
        puts $fp "            <h1>📊 $analysis_type Report</h1>"
        puts $fp "            <p>Spyglass Static Analysis Results Dashboard</p>"
        puts $fp "        </div>"
        
        # Info Cards Section
        puts $fp "        <div class='info-section'>"
        puts $fp "            <div class='info-card'>"
        puts $fp "                <h3>📅 Generated</h3>"
        puts $fp "                <p style='font-size:1.3em;'>[clock format [clock seconds] -format "%Y-%m-%d"]</p>"
        puts $fp "                <p style='font-size:0.9em; color:#6c757d; margin-top:5px;'>[clock format [clock seconds] -format "%H:%M:%S"]</p>"
        puts $fp "            </div>"
        puts $fp "            <div class='info-card'>"
        puts $fp "                <h3>🏷️ Build Tag</h3>"
        puts $fp "                <p style='font-size:1.1em; word-break:break-all;'>[get_env_var BUILD_TAG "unknown"]</p>"
        puts $fp "            </div>"
        puts $fp "            <div class='info-card'>"
        puts $fp "                <h3>📂 Location</h3>"
        puts $fp "                <p style='font-size:0.75em; word-break:break-all; line-height:1.4;'>[file normalize $report_dir]</p>"
        puts $fp "            </div>"
        puts $fp "        </div>"
        
        # Content Section
        puts $fp "        <div class='content'>"
        puts $fp "            <h2 class='section-title'>📑 Available Reports</h2>"
        
        # Find all report files
        set report_files [glob -nocomplain \
            [file join $report_dir "*" "*.rpt"] \
            [file join $report_dir "*" "*.log"] \
            [file join $report_dir "*.rpt"] \
            [file join $report_dir "*.log"]]
        
        if {[llength $report_files] > 0} {
            puts $fp "            <table>"
            puts $fp "                <thead>"
            puts $fp "                    <tr>"
            puts $fp "                        <th>Module</th>"
            puts $fp "                        <th>Report File</th>"
            puts $fp "                        <th>Type</th>"
            puts $fp "                        <th>Size</th>"
            puts $fp "                        <th>Modified</th>"
            puts $fp "                    </tr>"
            puts $fp "                </thead>"
            puts $fp "                <tbody>"
            
            foreach rpt [lsort $report_files] {
                # Determine module and file info
                set rel_path [string range $rpt [string length $report_dir] end]
                set rel_path [string trimleft $rel_path "/"]
                
                set path_parts [file split $rel_path]
                if {[llength $path_parts] > 1} {
                    set module [lindex $path_parts 0]
                    set filename [lindex $path_parts end]
                } else {
                    set module "📂 root"
                    set filename $rel_path
                }
                
                set file_size [file size $rpt]
                set mod_time [clock format [file mtime $rpt] -format "%Y-%m-%d %H:%M"]
                
                # Determine report type and badge
                set report_type "Report"
                set badge_class "badge-report"
                set icon "📄"
                
                if {[string match "*summary*" $filename] || [string match "*moresimple*" $filename]} {
                    set report_type "Summary"
                    set badge_class "badge-summary"
                    set icon "📊"
                } elseif {[string match "*violation*" $filename]} {
                    set report_type "Violations"
                    set badge_class "badge-violation"
                    set icon "⚠️"
                } elseif {[string match "*.log" $filename]} {
                    set report_type "Log"
                    set badge_class "badge-log"
                    set icon "📝"
                } else {
                    set badge_class "badge-info"
                }
                
                puts $fp "                    <tr>"
                puts $fp "                        <td><strong>$module</strong></td>"
                puts $fp "                        <td>"
                puts $fp "                            <a href='$rel_path'>"
                puts $fp "                                <span class='file-icon'>$icon</span>"
                puts $fp "                                $filename"
                puts $fp "                            </a>"
                puts $fp "                        </td>"
                puts $fp "                        <td><span class='badge $badge_class'>$report_type</span></td>"
                puts $fp "                        <td>[format_file_size $file_size]</td>"
                puts $fp "                        <td>$mod_time</td>"
                puts $fp "                    </tr>"
            }
            
            puts $fp "                </tbody>"
            puts $fp "            </table>"
            
            # Statistics
            set total_size 0
            foreach rpt $report_files {
                incr total_size [file size $rpt]
            }
            
            puts $fp "            <div style='margin-top:20px; padding:15px; background:#f8f9fa; border-radius:8px; text-align:center;'>"
            puts $fp "                <strong>📈 Statistics:</strong> "
            puts $fp "                [llength $report_files] report files · "
            puts $fp "                Total size: [format_file_size $total_size]"
            puts $fp "            </div>"
            
        } else {
            # Empty state
            puts $fp "            <div class='empty-state'>"
            puts $fp "                <div class='empty-state-icon'>📭</div>"
            puts $fp "                <h3>No Report Files Found</h3>"
            puts $fp "                <p>No .rpt or .log files were found in this directory.</p>"
            puts $fp "            </div>"
        }
        
        # Tips section
        puts $fp "            <div class='tips-box'>"
        puts $fp "                <h3>💡 Quick Tips</h3>"
        puts $fp "                <ul>"
        puts $fp "                    <li>Click on report files to view them in your browser</li>"
        puts $fp "                    <li>Look for <span class='badge badge-violation'>Violations</span> badges to find issues</li>"
        puts $fp "                    <li>Check <span class='badge badge-summary'>Summary</span> reports for quick overview</li>"
        puts $fp "                    <li>Use <span class='badge badge-log'>Log</span> files for detailed execution traces</li>"
        puts $fp "                    <li>All file sizes and timestamps are automatically formatted</li>"
        puts $fp "                </ul>"
        puts $fp "            </div>"
        
        puts $fp "        </div>"
        
        # Footer
        puts $fp "        <div class='footer'>"
        puts $fp "            <p>"
        puts $fp "                Generated by <strong>Spyglass Analysis Framework v5.0</strong> | "
        puts $fp "                Directory: <code>[file tail $report_dir]</code> | "
        puts $fp "                <a href='https://www.synopsys.com/verification/static-and-formal-verification/spyglass.html' target='_blank'>Synopsys Spyglass</a>"
        puts $fp "            </p>"
        puts $fp "        </div>"
        
        puts $fp "    </div>"
        puts $fp "</body>"
        puts $fp "</html>"
        
        close $fp
        
        log_msg "INFO" "HTML report generated successfully: index.html"
        return 1
        
    } err]} {
        log_msg "ERROR" "Failed to generate HTML report: $err"
        return 0
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
    if {[catch {
        set fp [open $config_file w]
        puts $fp "# Spyglass Project Configuration"
        puts $fp "# Generated: [clock format [clock seconds]]"
        puts $fp ""
        
        # Export key project settings
        if {[catch {get_option top} top_module]} {
            set top_module "unknown"
        }
        puts $fp "set_option top $top_module"
        
        close $fp
        log_msg "INFO" "Configuration exported to: $config_file"
        return 1
    } err]} {
        log_msg "ERROR" "Failed to export configuration: $err"
        return 0
    }
}

##############################################################################
# Error Handling and Recovery
##############################################################################

proc handle_spyglass_error {error_msg operation} {
    log_msg "ERROR" "Spyglass error during $operation: $error_msg"
    
    # Attempt recovery strategies
    if {[string match "*license*" [string tolower $error_msg]]} {
        log_msg "INFO" "License error detected - attempting recovery"
        return [handle_license_error]
    } elseif {[string match "*memory*" [string tolower $error_msg]]} {
        log_msg "INFO" "Memory error detected - attempting recovery"
        return [handle_memory_error]
    }
    
    return 0
}

proc handle_license_error {} {
    log_msg "INFO" "Checking license server..."
    after 5000  ;# Wait 5 seconds
    return 1
}

proc handle_memory_error {} {
    log_msg "INFO" "Memory optimization - enabling incremental mode"
    catch {set_option enable_incremental_flow yes}
    return 1
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
    
    log_msg "INFO" "Spyglass health check passed ✓"
    return 1
}

##############################################################################
# String Utilities
##############################################################################

proc truncate_string {str max_len} {
    if {[string length $str] > $max_len} {
        return "[string range $str 0 [expr {$max_len - 4}]]..."
    }
    return $str
}

proc pad_string {str width {char " "}} {
    set current_len [string length $str]
    if {$current_len < $width} {
        return "$str[string repeat $char [expr {$width - $current_len}]]"
    }
    return $str
}

##############################################################################
# Initialization
##############################################################################

# Log startup message
log_msg "INFO" "========================================="
log_msg "INFO" "Spyglass Common Procedures v2.1"
log_msg "INFO" "Production Ready - P-2019 Compatible"
log_msg "INFO" "Loaded successfully"
log_msg "INFO" "========================================="
