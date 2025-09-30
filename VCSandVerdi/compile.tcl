# ============================================================================
# VCS Compilation Control Script - Fixed for VCS compatibility
# ============================================================================

set compile_start_time [clock seconds]

# VCS-compatible compilation monitoring
proc report_compile_status {} {
    global compile_start_time
    set compile_end_time [clock seconds]
    set compile_duration [expr $compile_end_time - $compile_start_time]
    
    puts "=== Compilation Summary ==="
    puts "Start time: [clock format $compile_start_time]"
    puts "End time: [clock format $compile_end_time]"
    puts "Duration: ${compile_duration} seconds"
    
    # Check for compilation errors in VCS log
    if {[file exists "compile.log"]} {
        set fp [open "compile.log" r]
        set log_content [read $fp]
        close $fp
        
        set error_count [regexp -all "Error" $log_content]
        set warning_count [regexp -all "Warning" $log_content]
        
        puts "Errors: $error_count"
        puts "Warnings: $warning_count"
        
        if {$error_count > 0} {
            puts "❌ Compilation FAILED - Check compile.log"
            return 1
        } else {
            puts "✅ Compilation SUCCESSFUL"
            return 0
        }
    }
}

# VCS-specific compilation optimizations
puts "VCS Compilation environment configured"
puts "Multi-threading enabled: -j8"
puts "Debug access: +acc+rw -debug_access+all"

# Call reporting function at the end
report_compile_status