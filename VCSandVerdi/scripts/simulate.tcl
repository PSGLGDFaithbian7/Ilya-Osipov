# scripts/simulate.tcl
# VCS Batch Mode Simulation Control
# Simplified for non-interactive execution

set sim_start_time [clock seconds]

puts "=== VCS Simulation Control Script ==="
puts "Started at: [clock format $sim_start_time -format {%Y-%m-%d %H:%M:%S}]"

# ============================================================================
# Environment Check
# ============================================================================
proc check_environment {} {
    puts "\n=== Environment Check ==="
    
    # Check for UVM mode
    if {[info exists ::env(UVM_TESTNAME)]} {
        puts "UVM Mode: Enabled"
        puts "Test Name: $::env(UVM_TESTNAME)"
        
        if {[info exists ::env(UVM_VERBOSITY)]} {
            puts "Verbosity: $::env(UVM_VERBOSITY)"
        }
    } else {
        puts "UVM Mode: Disabled"
    }
    
    # Check for coverage
    if {[info exists ::env(COV_ENABLE)]} {
        puts "Coverage: Enabled"
    }
    
    # Check for performance analysis
    if {[info exists ::env(PERF_ANALYSIS)]} {
        puts "Performance Analysis: Enabled"
    }
    
    # Check for AI chip mode
    if {[info exists ::env(AI_CHIP_MODE)]} {
        puts "AI Chip Mode: Enabled"
    }
}

# ============================================================================
# Simulation Configuration
# ============================================================================
proc configure_simulation {} {
    puts "\n=== Simulation Configuration ==="
    
    # Get simulation parameters from environment
    set num_cases 1000
    set seed 0
    set timeout 50000
    
    if {[info exists ::env(NUM_CASES)]} {
        set num_cases $::env(NUM_CASES)
    }
    
    if {[info exists ::env(SEED)]} {
        set seed $::env(SEED)
    }
    
    if {[info exists ::env(TIMEOUT_CYCLES)]} {
        set timeout $::env(TIMEOUT_CYCLES)
    }
    
    puts "Number of cases: $num_cases"
    puts "Random seed: $seed"
    puts "Timeout cycles: $timeout"
}

# ============================================================================
# Post-Simulation Summary
# ============================================================================
proc simulation_summary {} {
    global sim_start_time
    
    set sim_end_time [clock seconds]
    set duration [expr $sim_end_time - $sim_start_time]
    
    puts "\n=== Simulation Summary ==="
    puts "Start: [clock format $sim_start_time -format {%Y-%m-%d %H:%M:%S}]"
    puts "End:   [clock format $sim_end_time -format {%Y-%m-%d %H:%M:%S}]"
    puts "Duration: $duration seconds ([expr $duration / 60] minutes)"
    
    # Check for log file
    if {[file exists "sim.log"]} {
        set fp [open "sim.log" r]
        set log_content [read $fp]
        close $fp
        
        # Extract statistics
        if {[regexp {CPU time: ([0-9.]+)} $log_content match cpu_time]} {
            puts "CPU Time: $cpu_time seconds"
        }
        
        if {[regexp {Memory.*: ([0-9.]+) [KMG]B} $log_content match memory]} {
            puts "Memory: $memory"
        }
        
        # Count errors and warnings
        set errors [regexp -all -nocase {error} $log_content]
        set warnings [regexp -all -nocase {warning} $log_content]
        
        puts "Errors: $errors"
        puts "Warnings: $warnings"
    }
}

# ============================================================================
# Main Execution
# ============================================================================

# Run environment checks
check_environment

# Configure simulation
configure_simulation

# Note: Actual simulation runs from VCS, not from this script
puts "\n=== Simulation Starting ==="
puts "Control will return to VCS..."

# The simulation_summary will be called at the end if needed
# For now, just indicate the script loaded successfully
puts "Simulation control script loaded successfully"
puts "======================================"