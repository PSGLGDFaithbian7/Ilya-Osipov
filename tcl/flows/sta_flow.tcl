#!/usr/bin/env pt_shell -f
#==============================================================================
# STA Flow Script
#==============================================================================

# Load configuration
source $::RUN_CONFIG

# Load all modules
set module_dir [file dirname [info script]]/../modules
foreach module [lsort [glob $module_dir/*.tcl]] {
    source $module
}

# Main flow
proc main {} {
    # Initialize
    ::PT::init_environment
    ::PT::init_logging
    
    # Setup
    ::PT::Setup::load_libraries
    ::PT::Setup::set_operating_conditions
    ::PT::Setup::configure_analysis_options
    
    # Read design
    ::PT::Netlist::read
    ::PT::Netlist::link
    ::PT::Netlist::read_spef
    
    # Apply constraints
    ::PT::Constraints::apply
    
    # Run STA
    ::PT::STA::analyze
    ::PT::STA::generate_reports
    ::PT::STA::analyze_critical_paths
    
    # Final reports
    ::PT::Reports::generate_qor
    ::PT::Reports::generate_summary
    ::PT::Reports::generate_debug_info
    
    # Timing summary
    ::PT::Utils::report_timing_summary
    
    puts "\n✓ STA Flow Complete"
}

# Execute
if {[catch {main} result]} {
    puts "ERROR: $result"
    puts $::errorInfo
    exit 1
}

exit 0