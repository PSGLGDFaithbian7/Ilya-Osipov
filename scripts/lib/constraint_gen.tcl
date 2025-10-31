#!/usr/bin/env tclsh
# =============================================================================
# Constraint Generator - Full Multi-Clock/Reset/IO Support
# =============================================================================

namespace eval ::constraint {
    
    # Apply clock constraints with FULL MULTI-CLOCK SUPPORT
    proc apply_clock_constraints {config} {
        set clocks [dict get $config clocks]
        set clock_names {}
        set clock_ports {}
        
        puts "######## CLOCK CONSTRAINTS ########"
        
        # Step 1: Create all clocks
        foreach clock_def $clocks {
            set name [dict get $clock_def name]
            set port [dict get $clock_def port]
            set period [dict get $clock_def period]
            set waveform [dict get $clock_def waveform]
            
            lappend clock_names $name
            lappend clock_ports $port
            
            # Create clock (hierarchical or top-level)
            if {[string first "/" $port] >= 0} {
                # Hierarchical pin
                create_clock -name $name -period $period \
                    -waveform $waveform [get_pins -hierarchical $port]
                set_dont_touch_network [get_pins -hierarchical $port]
                set_ideal_network -no_propagate [get_pins -hierarchical $port]
            } else {
                # Top-level port
                remove_driving_cell [get_ports $port]
                set_drive 0 [get_ports $port]
                create_clock -name $name -period $period \
                    -waveform $waveform [get_ports $port]
                set_ideal_network -no_propagate [get_ports $port]
            }
            
            # Clock uncertainty
            set unc [dict get $clock_def uncertainty]
            set_clock_uncertainty -setup [dict get $unc setup] [get_clocks $name]
            set_clock_uncertainty -hold [dict get $unc hold] [get_clocks $name]
            
            # Clock latency
            set lat [dict get $clock_def latency]
            set_clock_latency -source -max [dict get $lat source_max] [get_clocks $name]
            set_clock_latency -source -min [dict get $lat source_min] [get_clocks $name]
            set_clock_latency -max [dict get $lat network_max] [get_clocks $name]
            set_clock_latency -min [dict get $lat network_min] [get_clocks $name]
            
            # Clock transition
            set tran [dict get $clock_def transition]
            set_clock_transition -max [dict get $tran max] [get_clocks $name]
            set_clock_transition -min [dict get $tran min] [get_clocks $name]
            
            puts "INFO: Created clock $name on port $port (period: $period ns)"
        }
        
        # Step 2: Handle clock relationships (CRITICAL FOR MULTI-CLOCK)
        if {[dict exists $config clocks clock_relationships]} {
            set relationships [dict get $config clocks clock_relationships]
            
            # Process asynchronous groups
            if {[dict exists $relationships asynchronous_groups]} {
                puts "######## ASYNCHRONOUS CLOCK GROUPS ########"
                foreach group [dict get $relationships asynchronous_groups] {
                    generate_false_paths_for_group $group
                }
            }
        } else {
            # DEFAULT BEHAVIOR: All clocks are asynchronous (like original)
            if {[llength $clock_names] > 1} {
                puts "######## AUTO-GENERATED FALSE PATHS ########"
                puts "INFO: No clock relationships defined, treating all clocks as asynchronous"
                
                # This is EXACTLY the original logic
                for {set i 0} {$i < [llength $clock_names]} {incr i} {
                    for {set j [expr {$i + 1}]} {$j < [llength $clock_names]} {incr j} {
                        set from_clk [lindex $clock_names $i]
                        set to_clk [lindex $clock_names $j]
                        
                        set_false_path -from [get_clocks $from_clk] -to [get_clocks $to_clk]
                        set_false_path -from [get_clocks $to_clk] -to [get_clocks $from_clk]
                        
                        puts "  False path: $from_clk <-> $to_clk"
                    }
                }
            }
        }
        
        return [list $clock_names $clock_ports]
    }
    
    # Generate false paths for clock group
    proc generate_false_paths_for_group {clock_group} {
        for {set i 0} {$i < [llength $clock_group]} {incr i} {
            for {set j [expr {$i + 1}]} {$j < [llength $clock_group]} {incr j} {
                set clk1 [lindex $clock_group $i]
                set clk2 [lindex $clock_group $j]
                
                set_false_path -from [get_clocks $clk1] -to [get_clocks $clk2]
                set_false_path -from [get_clocks $clk2] -to [get_clocks $clk1]
                
                puts "  False path set: $clk1 <-> $clk2"
            }
        }
    }
    
    # Apply MULTIPLE RESET constraints
    proc apply_reset_constraints {config} {
        set resets [dict get $config resets]
        set reset_ports {}
        
        puts "######## RESET CONSTRAINTS ########"
        
        foreach reset_def $resets {
            set name [dict get $reset_def name]
            set port [dict get $reset_def port]
            
            lappend reset_ports $port
            
            # Apply all reset constraints (same as original)
            set_dont_touch_network [get_ports $port]
            set_false_path -from [get_ports $port]
            set_ideal_network -no_propagate [get_ports $port]
            set_drive 0 [get_ports $port]
            
            puts "INFO: Applied constraints to reset $name on port $port"
        }
        
        return $reset_ports
    }
    
    # Apply MULTIPLE IO constraints
    proc apply_io_constraints {config clock_names clock_ports reset_ports} {
        set io_config [dict get $config io_constraints]
        
        puts "######## IO CONSTRAINTS ########"
        
        # Global defaults
        if {[dict exists $io_config global_defaults]} {
            set defaults [dict get $io_config global_defaults]
            set default_load [dict get $defaults output_load 5.0]
            set_load $default_load [all_outputs]
        }
        
        # Process multiple input groups
        if {[dict exists $io_config inputs]} {
            foreach input_group [dict get $io_config inputs] {
                set ports [dict get $input_group ports]
                set clock [dict get $input_group clock]
                set max_delay [dict get $input_group max_delay]
                set min_delay [dict get $input_group min_delay]
                
                foreach port_pattern $ports {
                    if {$port_pattern eq "all_except_clk_rst"} {
                        # Special case: all inputs except clock and reset
                        set excluded_ports [concat $clock_ports $reset_ports]
                        set port_collection [remove_from_collection [all_inputs] [get_ports $excluded_ports]]
                    } else {
                        set port_collection [get_ports -quiet $port_pattern]
                    }
                    
                    if {[sizeof_collection $port_collection] > 0} {
                        set_input_delay -max $max_delay -clock [get_clocks $clock] $port_collection
                        set_input_delay -min $min_delay -clock [get_clocks $clock] $port_collection
                        puts "  Input delays set for: $port_pattern (clock: $clock)"
                    }
                }
            }
        }
        
        # Process multiple output groups
        if {[dict exists $io_config outputs]} {
            foreach output_group [dict get $io_config outputs] {
                set ports [dict get $output_group ports]
                set clock [dict get $output_group clock]
                set max_delay [dict get $output_group max_delay]
                set min_delay [dict get $output_group min_delay]
                set load [dict get $output_group load 5.0]
                
                foreach port_pattern $ports {
                    if {$port_pattern eq "all"} {
                        set port_collection [all_outputs]
                    } else {
                        set port_collection [get_ports -quiet $port_pattern]
                    }
                    
                    if {[sizeof_collection $port_collection] > 0} {
                        set_output_delay -max $max_delay -clock [get_clocks $clock] $port_collection
                        set_output_delay -min $min_delay -clock [get_clocks $clock] $port_collection
                        set_load $load $port_collection
                        puts "  Output delays set for: $port_pattern (clock: $clock)"
                    }
                }
            }
        }
    }
    
    # Apply environmental constraints
    proc apply_environmental_constraints {config} {
        puts "######## ENVIRONMENTAL CONSTRAINTS ########"
        
        # Operating conditions
        if {[dict exists $config library operating_conditions]} {
            set op_conds [dict get $config library operating_conditions]
            set worst [dict get $op_conds worst]
            set lib_name [dict get $op_conds library_name]
            set_operating_conditions -max $worst -max_library $lib_name
            puts "  Operating conditions: $worst"
        }
        
        # Wire load
        if {[dict exists $config library wire_load]} {
            set wire_load [dict get $config library wire_load]
            set_wire_load_mode [dict get $wire_load mode]
            set_wire_load_selection [dict get $wire_load selection]
            puts "  Wire load mode: [dict get $wire_load mode]"
        }
        
        # High fanout
        set synth_opts [dict get $config synthesis]
        set_app_var high_fanout_net_threshold [dict get $synth_opts advanced high_fanout_threshold]
        set_app_var high_fanout_net_pin_capacitance [dict get $synth_opts advanced high_fanout_pin_cap]
    }
    
    # Setup path groups
    proc setup_path_groups {clock_names} {
        puts "######## PATH GROUPS ########"
        
        foreach clk $clock_names {
            set CLK_PERIOD [get_attribute [get_clocks $clk] period]
            group_path -name $clk -weight 5 -critical_range [expr $CLK_PERIOD * 0.10]
            puts "  Path group created for clock: $clk"
        }
        
        group_path -name INPUTS -weight 3 -critical_range 0.5 -from [all_inputs]
        group_path -name OUTPUTS -weight 3 -critical_range 0.5 -to [all_outputs]
        group_path -name COMB -weight 2 -critical_range 0.5 -from [all_inputs] -to [all_outputs]
        
        puts "  Created standard path groups: INPUTS, OUTPUTS, COMB"
    }
}