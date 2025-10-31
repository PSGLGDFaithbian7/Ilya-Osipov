#!/usr/bin/env tclsh
# =============================================================================
# QoR Analyzer - TCL Version
# =============================================================================

namespace eval ::qor {
    variable metrics
    variable report_dir
    variable output_file
    
    proc analyze {args} {
        variable metrics
        variable report_dir
        variable output_file
        
        # Parse arguments
        set i 0
        while {$i < [llength $args]} {
            set arg [lindex $args $i]
            switch -- $arg {
                "--report-dir" {
                    set report_dir [lindex $args [incr i]]
                }
                "--output" {
                    set output_file [lindex $args [incr i]]
                }
            }
            incr i
        }
        
        # Initialize metrics
        array set metrics {
            setup_slack "N/A"
            hold_slack "N/A"
            total_area "N/A"
            dynamic_power "N/A"
            leakage_power "N/A"
            clock_period "N/A"
            critical_paths 0
            total_violations 0
            status "UNKNOWN"
        }
        
        # Parse reports
        parse_timing_reports
        parse_area_reports
        parse_power_reports
        
        # Generate summary
        generate_summary
        
        # Generate HTML report
        generate_html_report
        
        return 0
    }
    
    proc parse_timing_reports {} {
        variable metrics
        variable report_dir
        
        # Find and parse setup timing report
        set timing_files [glob -nocomplain -directory "$report_dir/timing" "*timing_setup.rpt"]
        if {[llength $timing_files] > 0} {
            set file [lindex $timing_files 0]
            if {[file exists $file]} {
                set fh [open $file r]
                set content [read $fh]
                close $fh
                
                # Extract setup slack
                if {[regexp {slack \(VIOLATED\)\s+(-?\d+\.?\d*)} $content match slack]} {
                    set metrics(setup_slack) $slack
                    incr metrics(total_violations)
                } elseif {[regexp {slack \(MET\)\s+(-?\d+\.?\d*)} $content match slack]} {
                    set metrics(setup_slack) $slack
                }
                
                # Count critical paths
                set critical_count [regexp -all {slack \(VIOLATED\)} $content]
                set metrics(critical_paths) $critical_count
            }
        }
        
        # Find and parse hold timing report
        set timing_files [glob -nocomplain -directory "$report_dir/timing" "*timing_hold.rpt"]
        if {[llength $timing_files] > 0} {
            set file [lindex $timing_files 0]
            if {[file exists $file]} {
                set fh [open $file r]
                set content [read $fh]
                close $fh
                
                # Extract hold slack
                if {[regexp {slack \(VIOLATED\)\s+(-?\d+\.?\d*)} $content match slack]} {
                    set metrics(hold_slack) $slack
                    incr metrics(total_violations)
                } elseif {[regexp {slack \(MET\)\s+(-?\d+\.?\d*)} $content match slack]} {
                    set metrics(hold_slack) $slack
                }
            }
        }
    }
    
    proc parse_area_reports {} {
        variable metrics
        variable report_dir
        
        set area_files [glob -nocomplain -directory "$report_dir/area" "*area*.rpt"]
        if {[llength $area_files] > 0} {
            set file [lindex $area_files 0]
            if {[file exists $file]} {
                set fh [open $file r]
                set content [read $fh]
                close $fh
                
                # Extract total area
                if {[regexp {Total\s+\d+\s+\d+\s+\d+\s+(\d+\.?\d*)} $content match area]} {
                    set metrics(total_area) $area
                }
            }
        }
    }
    
    proc parse_power_reports {} {
        variable metrics
        variable report_dir
        
        set power_files [glob -nocomplain -directory "$report_dir/power" "*power*.rpt"]
        if {[llength $power_files] > 0} {
            set file [lindex $power_files 0]
            if {[file exists $file]} {
                set fh [open $file r]
                set content [read $fh]
                close $fh
                
                # Extract dynamic power
                if {[regexp {Total Dynamic Power\s+=\s+(\d+\.?\d*)\s+(\w+)} $content match value unit]} {
                    set power $value
                    # Convert to mW
                    if {$unit eq "uW"} {
                        set power [expr {$power / 1000.0}]
                    } elseif {$unit eq "W"} {
                        set power [expr {$power * 1000.0}]
                    }
                    set metrics(dynamic_power) [format "%.3f" $power]
                }
                
                # Extract leakage power
                if {[regexp {Cell Leakage Power\s+=\s+(\d+\.?\d*)\s+(\w+)} $content match value unit]} {
                    set power $value
                    if {$unit eq "uW"} {
                        set power [expr {$power / 1000.0}]
                    } elseif {$unit eq "W"} {
                        set power [expr {$power * 1000.0}]
                    }
                    set metrics(leakage_power) [format "%.3f" $power]
                }
            }
        }
    }
    
    proc generate_summary {} {
        variable metrics
        
        # Determine overall status
        set metrics(status) "PASS"
        
        if {$metrics(setup_slack) ne "N/A" && $metrics(setup_slack) < 0} {
            set metrics(status) "FAIL"
        }
        if {$metrics(hold_slack) ne "N/A" && $metrics(hold_slack) < 0} {
            set metrics(status) "FAIL"
        }
        if {$metrics(total_violations) > 0} {
            set metrics(status) "FAIL"
        }
        
        # Write text summary
        set summary_file "[file dirname $::qor::output_file]/qor_summary.txt"
        set fh [open $summary_file w]
        
        puts $fh "QoR Summary:"
        puts $fh "  Status: $metrics(status)"
        puts $fh "  Setup Slack: $metrics(setup_slack) ns"
        puts $fh "  Hold Slack: $metrics(hold_slack) ns"
        puts $fh "  Total Area: $metrics(total_area) um²"
        puts $fh "  Dynamic Power: $metrics(dynamic_power) mW"
        puts $fh "  Leakage Power: $metrics(leakage_power) mW"
        puts $fh "  Critical Paths: $metrics(critical_paths)"
        puts $fh "  Total Violations: $metrics(total_violations)"
        
        close $fh
    }
    
    proc generate_html_report {} {
        variable metrics
        variable output_file
        
        set html {<!DOCTYPE html>
<html>
<head>
    <title>QoR Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .status-pass { color: green; font-weight: bold; font-size: 24px; }
        .status-fail { color: red; font-weight: bold; font-size: 24px; }
        .status-unknown { color: orange; font-weight: bold; font-size: 24px; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th { background-color: #007bff; color: white; padding: 12px; text-align: left; }
        td { border: 1px solid #ddd; padding: 10px; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .metric-value { font-weight: bold; color: #333; }
        .good { color: green; }
        .bad { color: red; }
        .warning { background-color: #fff3cd; padding: 10px; border-radius: 5px; margin: 10px 0; }
        .summary-box { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>QoR Analysis Report</h1>
        }
        
        # Add timestamp
        append html "<p>Generated: [clock format [clock seconds]]</p>"
        
        # Status box
        append html {<div class="summary-box">}
        set status_class [string tolower $metrics(status)]
        append html "<h2>Overall Status: <span class='status-$status_class'>$metrics(status)</span></h2>"
        
        if {$metrics(total_violations) > 0} {
            append html "<p class='warning'>⚠ Found $metrics(total_violations) timing violations</p>"
        }
        append html {</div>}
        
        # Timing metrics table
        append html {
        <h2>Timing Metrics</h2>
        <table>
            <tr><th>Metric</th><th>Value</th><th>Status</th></tr>}
        
        # Setup slack
        set setup_status "✓"
        set setup_class "good"
        if {$metrics(setup_slack) ne "N/A" && $metrics(setup_slack) < 0} {
            set setup_status "✗"
            set setup_class "bad"
        }
        append html "<tr><td>Setup Slack</td><td class='metric-value'>$metrics(setup_slack) ns</td><td class='$setup_class'>$setup_status</td></tr>"
        
        # Hold slack
        set hold_status "✓"
        set hold_class "good"
        if {$metrics(hold_slack) ne "N/A" && $metrics(hold_slack) < 0} {
            set hold_status "✗"
            set hold_class "bad"
        }
        append html "<tr><td>Hold Slack</td><td class='metric-value'>$metrics(hold_slack) ns</td><td class='$hold_class'>$hold_status</td></tr>"
        
        append html "<tr><td>Critical Paths</td><td class='metric-value'>$metrics(critical_paths)</td><td>-</td></tr>"
        append html {</table>}
        
        # Area metrics
        append html {
        <h2>Area Metrics</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>}
        append html "<tr><td>Total Area</td><td class='metric-value'>$metrics(total_area) µm²</td></tr>"
        append html {</table>}
        
        # Power metrics
        append html {
        <h2>Power Metrics</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>}
        append html "<tr><td>Dynamic Power</td><td class='metric-value'>$metrics(dynamic_power) mW</td></tr>"
        append html "<tr><td>Leakage Power</td><td class='metric-value'>$metrics(leakage_power) mW</td></tr>"
        
        set total_power "N/A"
        if {$metrics(dynamic_power) ne "N/A" && $metrics(leakage_power) ne "N/A"} {
            set total_power [format "%.3f" [expr {$metrics(dynamic_power) + $metrics(leakage_power)}]]
        }
        append html "<tr><td><strong>Total Power</strong></td><td class='metric-value'><strong>$total_power mW</strong></td></tr>"
        append html {</table>}
        
        append html {
    </div>
</body>
</html>}
        
        # Write HTML file
        set fh [open $output_file w]
        puts $fh $html
        close $fh
        
        puts "QoR Analysis Complete"
        puts "  Status: $metrics(status)"
        puts "  Report: $output_file"
    }
}

# Main execution
if {[info exists argv0] && [file tail $argv0] eq "qor_analyzer.tcl"} {
    exit [qor::analyze {*}$argv]
}