# ============================================================================
# UCLI/TCL Simulation Control Script - Fixed for VCS UCLI
# Enhanced for Arithmetic Unit and AI Chip Testing
# ============================================================================

set sim_start_time [clock seconds]

# VCS UCLI compatible performance monitoring
proc setup_performance_monitoring {} {
    puts "=== Setting up VCS performance monitoring ==="
    
    # Use VCS built-in coverage commands instead of custom counters
    if {[info exists ::env(PERF_ANALYSIS)]} {
        puts "Performance analysis mode enabled"
        # VCS coverage commands can be used here
        # coverage configure -cvgmax 1000000
    }
}

# UVM Phase Control - VCS compatible
proc uvm_phase_control {} {
    if {[info exists ::env(UVM_TESTNAME)]} {
        set test_name $::env(UVM_TESTNAME)
        puts "Running UVM test: $test_name"
        
        # Set VCS UVM timeout - use +UVM_TIMEOUT instead of set_param
        switch -regexp $test_name {
            ".*random.*" {
                puts "Setting extended timeout for random test"
            }
            ".*performance.*" {
                puts "Setting extended timeout for performance test"
            }
            default {
                puts "Using default timeout for test: $test_name"
            }
        }
    }
}

# VCS UCLI breakpoint management
proc setup_debug_breakpoints {} {
    puts "=== Setting up UCLI breakpoints ==="
    
    # VCS UCLI breakpoint syntax
    # These will only work if signals exist and are accessible
    catch {
        ucli add_bp -scope tb_top.dut -signal overflow_detected -condition "overflow_detected == 1'b1"
        puts "Breakpoint set for overflow detection"
    }
    
    catch {
        ucli add_bp -scope tb_top.dut -signal underflow_detected -condition "underflow_detected == 1'b1"  
        puts "Breakpoint set for underflow detection"
    }
    
    puts "Debug breakpoints configured (if signals exist)"
}

# Main simulation initialization
proc initialize_simulation {} {
    puts "=== Initializing VCS UCLI Simulation Environment ==="
    
    # Note: FSDB dumping moved to SystemVerilog testbench
    puts "FSDB dumping should be configured in SystemVerilog testbench"
    
    # Setup performance monitoring
    setup_performance_monitoring
    
    # Configure UVM if enabled
    uvm_phase_control
    
    # Setup debug environment
    setup_debug_breakpoints
    
    # AI chip specific initialization
    if {[info exists ::env(AI_CHIP_MODE)]} {
        puts "AI Chip mode enabled"
        # Add AI-specific UCLI commands here
    }
    
    puts "VCS UCLI simulation environment ready"
}

# Simulation completion handler - will be called manually
proc simulation_complete {} {
    global sim_start_time
    
    set sim_end_time [clock seconds]
    set sim_duration [expr $sim_end_time - $sim_start_time]
    
    puts "=== Simulation Complete ==="
    puts "Duration: ${sim_duration} seconds"
    
    # Check for simulation statistics from VCS
    if {[file exists "sim.log"]} {
        set fp [open "sim.log" r]
        set log_content [read $fp]
        close $fp
        
        # Extract VCS simulation statistics
        if {[regexp {CPU time: ([0-9.]+) seconds} $log_content match cpu_time]} {
            puts "CPU time: $cpu_time seconds"
        }
        
        if {[regexp {Memory usage: ([0-9.]+) MB} $log_content match memory]} {
            puts "Memory usage: $memory MB"
        }
    }
    
    # Auto-launch Verdi if requested
    if {[info exists ::env(AUTO_DEBUG)]} {
        puts "Auto-launching Verdi..."
        exec verdi -ssf *.fsdb -nologo &
    }
}

# Initialize simulation
initialize_simulation

# VCS UCLI simulation control commands
puts "=== Available VCS UCLI Commands ==="
puts "  run                - Run simulation"
puts "  run <time>         - Run for specified time"  
puts "  stop               - Stop simulation"
puts "  step               - Single step"
puts "  finish             - Finish simulation"
puts "  show_signals       - Show accessible signals"
puts "  show_scopes        - Show design hierarchy"

# Define UCLI-compatible procedures
proc run_full {} {
    puts "Running full simulation..."
    run
    simulation_complete
}

proc run_cycles {n} {
    puts "Running for $n time units..."
    run $n
}

proc show_signals {} {
    puts "Available signals in current scope:"
    # Use VCS UCLI command to list signals
    catch {ucli list_signals} result
    puts $result
}

proc show_scopes {} {
    puts "Design hierarchy:"
    catch {ucli list_scopes} result
    puts $result
}

proc launch_verdi {} {
    puts "Launching Verdi with available FSDB files..."
    set fsdb_files [glob -nocomplain *.fsdb]
    if {[llength $fsdb_files] > 0} {
        set fsdb_file [lindex $fsdb_files 0]
        exec verdi -ssf $fsdb_file -nologo &
        puts "Verdi launched with $fsdb_file"
    } else {
        puts "No FSDB files found"
    }
}

# Print help
puts "Type 'run_full' to start simulation"
puts "Type 'simulation_complete' when done to see statistics"