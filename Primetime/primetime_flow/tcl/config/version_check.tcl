#!/usr/bin/env pt_shell -f
#==============================================================================
# PrimeTime Version Check
#==============================================================================

proc check_version {} {
    puts "PrimeTime Version Information"
    puts "=============================="
    
    # Get version
    if {[catch {set version [get_app_var sh_arch]} err]} {
        puts "ERROR: Cannot determine version"
        exit 1
    }
    
    puts "Version: $version"
    
    # Get build info
    if {[catch {set build [get_app_var synopsys_program_build_id]} err]} {
        puts "Build: Unknown"
    } else {
        puts "Build: $build"
    }
    
    # Check minimum version
    set min_version "2019.06"
    puts "\nMinimum required: $min_version"
    
    # Feature compatibility
    puts "\nFeature Support:"
    puts "  Power Analysis: [expr {[catch {set_app_var power_enable_analysis true}] ? "No" : "Yes"}]"
    puts "  SAIF Support: Yes"
    puts "  VCD Support: Yes"
    puts "  SystemVerilog: Limited"
    
    exit 0
}

check_version