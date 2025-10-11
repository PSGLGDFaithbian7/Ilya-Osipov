# scripts/report.tcl
# Enhanced Simulation Report Generator
# Parses logs and generates comprehensive reports

puts "\n=========================================="
puts "   Simulation Report Generator"
puts "=========================================="

# ============================================================================
# Configuration
# ============================================================================
set report_file "simulation_report.txt"
set html_report "simulation_report.html"
set log_file "sim.log"
set compile_log "compile.log"

# ============================================================================
# Parse Compilation Log
# ============================================================================
proc parse_compile_log {logfile} {
    if {![file exists $logfile]} {
        puts "WARNING: Compile log not found: $logfile"
        return [dict create status "UNKNOWN"]
    }
    
    puts "\n=== Compilation Analysis ==="
    
    set fp [open $logfile r]
    set content [read $fp]
    close $fp
    
    set stats [dict create \
        modules 0 \
        warnings 0 \
        errors 0 \
        status "UNKNOWN" \
    ]
    
    # Count modules
    set module_count [regexp -all {Compiling module} $content]
    dict set stats modules $module_count
    
    # Count warnings and errors
    dict set stats warnings [regexp -all -nocase {Warning} $content]
    dict set stats errors [regexp -all -nocase {Error} $content]
    
    # Determine status
    if {[dict get $stats errors] > 0} {
        dict set stats status "FAILED"
    } elseif {$module_count > 0} {
        dict set stats status "SUCCESS"
    }
    
    puts "Modules compiled: $module_count"
    puts "Warnings: [dict get $stats warnings]"
    puts "Errors: [dict get $stats errors]"
    puts "Status: [dict get $stats status]"
    
    return $stats
}

# ============================================================================
# Parse Simulation Log
# ============================================================================
proc parse_simulation_log {logfile} {
    if {![file exists $logfile]} {
        puts "WARNING: Simulation log not found: $logfile"
        return [dict create status "UNKNOWN"]
    }
    
    puts "\n=== Simulation Analysis ==="
    
    set fp [open $logfile r]
    set content [read $fp]
    close $fp
    
    # Initialize statistics
    set stats [dict create \
        status "UNKNOWN" \
        pass_count 0 \
        fail_count 0 \
        total_tests 0 \
        errors 0 \
        warnings 0 \
        coverage 0.0 \
        sim_time "N/A" \
        cpu_time "N/A" \
    ]
    
    # Extract test results (支持中英文)
    if {[regexp {通过[: ]+(\d+)} $content match pass] || \
        [regexp {Pass[: ]+(\d+)} $content match pass] || \
        [regexp {Passed[: ]+(\d+)} $content match pass]} {
        dict set stats pass_count $pass
    }
    
    if {[regexp {失败[: ]+(\d+)} $content match fail] || \
        [regexp {Fail[: ]+(\d+)} $content match fail] || \
        [regexp {Failed[: ]+(\d+)} $content match fail]} {
        dict set stats fail_count $fail
    }
    
    # Calculate total
    set total [expr {[dict get $stats pass_count] + [dict get $stats fail_count]}]
    dict set stats total_tests $total
    
    # Calculate pass rate
    if {$total > 0} {
        set pass_rate [expr {[dict get $stats pass_count] * 100.0 / $total}]
        dict set stats pass_rate $pass_rate
    } else {
        dict set stats pass_rate 0.0
    }
    
    # Extract errors and warnings
    dict set stats errors [regexp -all -nocase {ERROR|错误} $content]
    dict set stats warnings [regexp -all -nocase {WARNING|警告} $content]
    
    # Extract simulation time
    if {[regexp {at time ([0-9.]+\s*[nuμm]?s)} $content match time]} {
        dict set stats sim_time $time
    }
    
    # Extract CPU time
    if {[regexp {CPU time[: ]+([0-9.]+)} $content match cpu]} {
        dict set stats cpu_time "$cpu seconds"
    }
    
    # Extract coverage
    if {[regexp {Coverage[: ]+([0-9.]+)%} $content match cov]} {
        dict set stats coverage $cov
    }
    
    # Determine status
    if {[dict get $stats fail_count] == 0 && [dict get $stats pass_count] > 0} {
        dict set stats status "PASSED"
    } elseif {[dict get $stats errors] > 0 || [dict get $stats fail_count] > 0} {
        dict set stats status "FAILED"
    }
    
    # Print summary
    puts "Total Tests:  [dict get $stats total_tests]"
    puts "Passed:       [dict get $stats pass_count]"
    puts "Failed:       [dict get $stats fail_count]"
    if {[dict exists $stats pass_rate]} {
        puts [format "Pass Rate:    %.2f%%" [dict get $stats pass_rate]]
    }
    puts "Errors:       [dict get $stats errors]"
    puts "Warnings:     [dict get $stats warnings]"
    puts "Coverage:     [dict get $stats coverage]%"
    puts "Status:       [dict get $stats status]"
    
    return $stats
}

# ============================================================================
# Generate Text Report
# ============================================================================
proc generate_text_report {compile_stats sim_stats filename} {
    set fp [open $filename w]
    
    puts $fp "=========================================="
    puts $fp "        SIMULATION REPORT"
    puts $fp "=========================================="
    puts $fp "Generated: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
    puts $fp ""
    
    puts $fp "=== Compilation ==="
    puts $fp "Modules:      [dict get $compile_stats modules]"
    puts $fp "Warnings:     [dict get $compile_stats warnings]"
    puts $fp "Errors:       [dict get $compile_stats errors]"
    puts $fp "Status:       [dict get $compile_stats status]"
    puts $fp ""
    
    puts $fp "=== Simulation ==="
    puts $fp "Total Tests:  [dict get $sim_stats total_tests]"
    puts $fp "Passed:       [dict get $sim_stats pass_count]"
    puts $fp "Failed:       [dict get $sim_stats fail_count]"
    if {[dict exists $sim_stats pass_rate]} {
        puts $fp [format "Pass Rate:    %.2f%%" [dict get $sim_stats pass_rate]]
    }
    puts $fp "Errors:       [dict get $sim_stats errors]"
    puts $fp "Warnings:     [dict get $sim_stats warnings]"
    puts $fp ""
    
    puts $fp "=== Coverage ==="
    puts $fp [format "Functional:   %.2f%%" [dict get $sim_stats coverage]]
    puts $fp ""
    
    puts $fp "=== Performance ==="
    puts $fp "Simulation Time: [dict get $sim_stats sim_time]"
    puts $fp "CPU Time:        [dict get $sim_stats cpu_time]"
    puts $fp ""
    
    puts $fp "=========================================="
    
    close $fp
    
    puts "Text report written to: $filename"
}

# ============================================================================
# Generate HTML Report
# ============================================================================
proc generate_html_report {compile_stats sim_stats filename} {
    set fp [open $filename w]
    
    puts $fp "<!DOCTYPE html>"
    puts $fp "<html><head>"
    puts $fp "<title>Simulation Report</title>"
    puts $fp "<style>"
    puts $fp "body { font-family: Arial, sans-serif; margin: 20px; }"
    puts $fp "h1 { color: #333; }"
    puts $fp "table { border-collapse: collapse; width: 100%; margin: 20px 0; }"
    puts $fp "th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }"
    puts $fp "th { background-color: #4CAF50; color: white; }"
    puts $fp ".pass { color: green; font-weight: bold; }"
    puts $fp ".fail { color: red; font-weight: bold; }"
    puts $fp "</style>"
    puts $fp "</head><body>"
    
    puts $fp "<h1>Simulation Report</h1>"
    puts $fp "<p>Generated: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]</p>"
    
    # Compilation table
    puts $fp "<h2>Compilation</h2>"
    puts $fp "<table>"
    puts $fp "<tr><th>Metric</th><th>Value</th></tr>"
    puts $fp "<tr><td>Modules</td><td>[dict get $compile_stats modules]</td></tr>"
    puts $fp "<tr><td>Warnings</td><td>[dict get $compile_stats warnings]</td></tr>"
    puts $fp "<tr><td>Errors</td><td>[dict get $compile_stats errors]</td></tr>"
    
    set comp_status [dict get $compile_stats status]
    set status_class [expr {$comp_status eq "SUCCESS" ? "pass" : "fail"}]
    puts $fp "<tr><td>Status</td><td class=\"$status_class\">$comp_status</td></tr>"
    puts $fp "</table>"
    
    # Simulation table
    puts $fp "<h2>Simulation</h2>"
    puts $fp "<table>"
    puts $fp "<tr><th>Metric</th><th>Value</th></tr>"
    puts $fp "<tr><td>Total Tests</td><td>[dict get $sim_stats total_tests]</td></tr>"
    puts $fp "<tr><td>Passed</td><td class=\"pass\">[dict get $sim_stats pass_count]</td></tr>"
    puts $fp "<tr><td>Failed</td><td class=\"fail\">[dict get $sim_stats fail_count]</td></tr>"
    
    if {[dict exists $sim_stats pass_rate]} {
        puts $fp [format "<tr><td>Pass Rate</td><td>%.2f%%</td></tr>" [dict get $sim_stats pass_rate]]
    }
    
    puts $fp "<tr><td>Errors</td><td>[dict get $sim_stats errors]</td></tr>"
    puts $fp "<tr><td>Warnings</td><td>[dict get $sim_stats warnings]</td></tr>"
    puts $fp [format "<tr><td>Coverage</td><td>%.2f%%</td></tr>" [dict get $sim_stats coverage]]
    puts $fp "<tr><td>Simulation Time</td><td>[dict get $sim_stats sim_time]</td></tr>"
    puts $fp "<tr><td>CPU Time</td><td>[dict get $sim_stats cpu_time]</td></tr>"
    
    set sim_status [dict get $sim_stats status]
    set status_class [expr {$sim_status eq "PASSED" ? "pass" : "fail"}]
    puts $fp "<tr><td>Status</td><td class=\"$status_class\">$sim_status</td></tr>"
    puts $fp "</table>"
    
    puts $fp "</body></html>"
    close $fp
    
    puts "HTML report written to: $filename"
}

# ============================================================================
# Display Console Summary
# ============================================================================
proc display_summary {sim_stats} {
    puts "\n=========================================="
    puts "        SIMULATION SUMMARY"
    puts "=========================================="
    puts [format "Status:       %s" [dict get $sim_stats status]]
    puts [format "Total Tests:  %d" [dict get $sim_stats total_tests]]
    puts [format "Passed:       %d" [dict get $sim_stats pass_count]]
    puts [format "Failed:       %d" [dict get $sim_stats fail_count]]
    
    if {[dict exists $sim_stats pass_rate]} {
        puts [format "Pass Rate:    %.2f%%" [dict get $sim_stats pass_rate]]
    }
    
    puts [format "Errors:       %d" [dict get $sim_stats errors]]
    puts [format "Warnings:     %d" [dict get $sim_stats warnings]]
    puts [format "Coverage:     %.2f%%" [dict get $sim_stats coverage]]
    puts "=========================================="
    
    if {[dict get $sim_stats status] eq "PASSED"} {
        puts "\n✓ Simulation PASSED"
        return 0
    } else {
        puts "\n✗ Simulation FAILED"
        return 1
    }
}

# ============================================================================
# Main Execution
# ============================================================================

# Parse logs
set compile_stats [parse_compile_log $compile_log]
set sim_stats [parse_simulation_log $log_file]

# Generate reports
generate_text_report $compile_stats $sim_stats $report_file
generate_html_report $compile_stats $sim_stats $html_report

# Display summary
set exit_code [display_summary $sim_stats]

exit $exit_code