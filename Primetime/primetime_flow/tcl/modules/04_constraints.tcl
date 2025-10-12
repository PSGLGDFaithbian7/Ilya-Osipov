#==============================================================================
# Module: Constraints
# Description: SDC constraints management
#==============================================================================

namespace eval ::PT::Constraints {}

proc ::PT::Constraints::apply {} {
    ::PT::print_header "Applying Constraints"
    
    set sdc $::CONFIG(SDC_FILE)
    
    if {[file exists $sdc]} {
        ::PT::Utils::safe_exec {
            read_sdc $sdc
        } "Reading SDC"
        
        verify
    } else {
        puts "WARNING: No SDC file, using defaults"
        apply_defaults
    }
    
    ::PT::Utils::checkpoint "constraints_applied"
}

proc ::PT::Constraints::apply_defaults {} {
    puts "Applying default constraints..."
    
    # Find clock ports
    set clk_ports [get_ports -quiet *clk*]
    
    if {[sizeof_collection $clk_ports] > 0} {
        set clk [index_collection $clk_ports 0]
        
        ::PT::Utils::safe_exec {
            create_clock -period $::CONFIG(CLOCK_PERIOD) $clk
        } "Creating clock"
        
        ::PT::Utils::safe_exec {
            set_input_delay -clock [get_clocks] \
                [expr {$::CONFIG(CLOCK_PERIOD) * 0.1}] \
                [remove_from_collection [all_inputs] $clk]
            
            set_output_delay -clock [get_clocks] \
                [expr {$::CONFIG(CLOCK_PERIOD) * 0.1}] \
                [all_outputs]
        } "Setting I/O delays"
    }
}

proc ::PT::Constraints::verify {} {
    puts "\nVerifying constraints..."
    
    ::PT::Utils::safe_exec {
        check_timing -verbose
    } "Checking timing"
    
    set num_clocks [sizeof_collection [all_clocks]]
    set num_unconstrained [sizeof_collection [all_registers -no_clock]]
    
    puts "Constraint summary:"
    puts "  Clocks defined: $num_clocks"
    puts "  Unconstrained registers: $num_unconstrained"
    
    if {$num_unconstrained > 0 && $::CONFIG(DEBUG)} {
        redirect -file "$::CONFIG(LOG_DIR)/unconstrained.log" {
            report_timing -to [all_registers -no_clock]
        }
    }
}