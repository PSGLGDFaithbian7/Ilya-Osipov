#==============================================================================
# Module: Debug
# Description: Debug utilities
#==============================================================================

namespace eval ::PT::Debug {}

proc ::PT::Debug::dump_state {tag} {
    if {!$::CONFIG(DEBUG)} return
    
    set file "$::CONFIG(LOG_DIR)/state_${tag}.log"
    redirect -file $file {
        puts "State: $tag"
        puts "Time: [clock format [clock seconds]]"
        puts ""
        report_design
        report_port -verbose
        report_clock -skew
        report_timing_summary
    }
    
    puts "DEBUG: State dumped to $file"
}

proc ::PT::Debug::interactive {} {
    if {!$::CONFIG(DEBUG)} return
    
    puts "\n=== Interactive Debug Mode ==="
    puts "Commands: continue, timing, power, quit"
    
    while {1} {
        puts -nonewline "debug> "
        flush stdout
        gets stdin cmd
        
        switch $cmd {
            "continue" { break }
            "timing" { report_timing }
            "power" { report_power }
            "quit" { exit 0 }
            default { catch {eval $cmd} result; puts $result }
        }
    }
}

proc ::PT::Debug::check_assertions {} {
    # Add design-specific assertions
    set errors {}
    
    # Check if design is linked
    if {[current_design] eq ""} {
        lappend errors "No current design"
    }
    
    # Check for clocks
    if {[sizeof_collection [all_clocks]] == 0} {
        lappend errors "No clocks defined"
    }
    
    if {[llength $errors] > 0} {
        puts "ASSERTION FAILURES:"
        foreach err $errors {
            puts "  - $err"
        }
    }
}