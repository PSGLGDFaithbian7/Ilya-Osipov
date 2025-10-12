#==============================================================================
# Module: Utilities
# Description: Common utility functions
#==============================================================================

namespace eval ::PT::Utils {
    variable checkpoint_count 0
    variable timing_log {}
}

proc ::PT::Utils::safe_exec {cmd description} {
    if {$::CONFIG(DEBUG)} {
        puts "DEBUG: Executing - $description"
        puts "DEBUG: Command - $cmd"
    }
    
    set start_time [clock milliseconds]
    
    if {[catch {eval $cmd} result]} {
        set error_file "$::CONFIG(LOG_DIR)/error_[clock seconds].log"
        set fp [open $error_file "w"]
        puts $fp "Error: $description"
        puts $fp "Command: $cmd"
        puts $fp "Result: $result"
        puts $fp "Stack:\n$::errorInfo"
        close $fp
        
        puts "ERROR: $description failed"
        puts "  Details: $error_file"
        
        if {!$::CONFIG(DEBUG)} {
            error $result
        }
        return ""
    }
    
    set elapsed [expr {[clock milliseconds] - $start_time}]
    lappend timing_log [list $description $elapsed]
    
    if {$::CONFIG(VERBOSE)} {
        puts "✓ $description (${elapsed}ms)"
    }
    
    return $result
}

proc ::PT::Utils::checkpoint {name} {
    variable checkpoint_count
    
    if {$::CONFIG(STEP_MODE)} {
        puts "\n=== Checkpoint: $name ==="
        puts "Press Enter to continue..."
        gets stdin
    }
    
    if {$::CONFIG(DEBUG)} {
        incr checkpoint_count
        set cp_file "$::CONFIG(CHECKPOINT_DIR)/${checkpoint_count}_${name}.db"
        
        safe_exec {
            write_file -format db -hierarchy -output $cp_file
        } "Saving checkpoint: $name"
    }
}

proc ::PT::Utils::measure_memory {} {
    if {[catch {exec ps -o rss= -p [pid]} mem]} {
        return "N/A"
    }
    return "[expr {$mem / 1024}] MB"
}

proc ::PT::Utils::report_timing_summary {} {
    variable timing_log
    
    puts "\n=== Execution Time Summary ==="
    set total 0
    foreach entry $timing_log {
        lassign $entry desc time
        puts [format "  %-40s : %6d ms" $desc $time]
        incr total $time
    }
    puts [format "  %-40s : %6d ms" "TOTAL" $total]
    puts ""
}