# scripts/debug.tcl
# Debug Helper Script for Interactive Simulation
# For use with: make sim_interactive

puts "=== Debug Helper Script Loaded ==="

# ============================================================================
# Signal Value Inspection
# ============================================================================
proc peek {signal_path} {
    puts "Value of $signal_path:"
    # In VCS GUI mode, you can examine signals
    puts "Use GUI signal viewer to inspect $signal_path"
}

# ============================================================================
# Breakpoint Helpers
# ============================================================================
proc bp_on_error {} {
    puts "Setting breakpoint on error conditions..."
    # VCS GUI breakpoint commands
    puts "Set breakpoint manually in GUI on error signals"
}

proc bp_on_signal {signal {condition ""}} {
    puts "Setting breakpoint on signal: $signal"
    if {$condition ne ""} {
        puts "Condition: $condition"
    }
    puts "Use GUI to set actual breakpoint"
}

# ============================================================================
# Quick Navigation
# ============================================================================
proc goto_time {time} {
    puts "Navigate to time: $time"
    puts "Use GUI timeline to navigate"
}

proc goto_error {} {
    puts "Navigating to first error..."
    puts "Use GUI log viewer to find errors"
}

# ============================================================================
# Waveform Helpers
# ============================================================================
proc show_all_signals {} {
    puts "Showing all signals in scope..."
    puts "Use GUI signal browser"
}

proc show_group {group_name} {
    puts "Showing signal group: $group_name"
}

# ============================================================================
# Print Available Commands
# ============================================================================
puts "Available debug commands:"
puts "  peek <signal>           - Show signal value"
puts "  bp_on_error             - Set breakpoint on errors"
puts "  bp_on_signal <sig> [cond] - Set conditional breakpoint"
puts "  goto_time <time>        - Navigate to time"
puts "  goto_error              - Navigate to first error"
puts "  show_all_signals        - Display all signals"
puts "  show_group <name>       - Show signal group"
puts ""
puts "Debug helper ready. Type commands in Tcl console."