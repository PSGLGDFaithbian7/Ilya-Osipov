#==============================================================================
# Module: Netlist
# Description: Netlist reading and linking
#==============================================================================

namespace eval ::PT::Netlist {}

proc ::PT::Netlist::read {} {
    ::PT::print_header "Reading Netlist"
    
    set netlist $::CONFIG(NETLIST)
    
    if {![file exists $netlist]} {
        error "Netlist not found: $netlist"
    }
    
    set ext [file extension $netlist]
    
    switch -nocase $ext {
        ".v" - ".verilog" {
            ::PT::Utils::safe_exec {
                read_verilog $netlist
            } "Reading Verilog"
        }
        ".sv" {
            puts "WARNING: SystemVerilog detected"
            ::PT::Utils::safe_exec {
                read_verilog -sv $netlist
            } "Reading SystemVerilog"
        }
        ".db" {
            ::PT::Utils::safe_exec {
                read_db $netlist
            } "Reading DB"
        }
        default {
            error "Unknown format: $ext"
        }
    }
    
    puts "✓ Netlist read successfully"
}

proc ::PT::Netlist::link {} {
    puts "\nLinking design..."
    
    ::PT::Utils::safe_exec {
        current_design $::CONFIG(DESIGN_NAME)
    } "Setting current design"
    
    ::PT::Utils::safe_exec {
        link_design
    } "Linking"
    
    # Report statistics
    set num_cells [sizeof_collection [all_registers]]
    set num_ports [sizeof_collection [all_inputs]]
    set num_nets [sizeof_collection [all_nets]]
    
    puts "Design statistics:"
    puts "  Cells: $num_cells"
    puts "  Ports: $num_ports"  
    puts "  Nets: $num_nets"
    
    ::PT::Utils::checkpoint "netlist_linked"
}

proc ::PT::Netlist::read_spef {} {
    set spef $::CONFIG(SPEF_FILE)
    
    if {[file exists $spef]} {
        puts "\nReading SPEF..."
        ::PT::Utils::safe_exec {
            read_parasitics -format spef $spef
        } "Reading parasitics"
        puts "✓ SPEF loaded"
    } else {
        puts "INFO: No SPEF file, using wire load models"
    }
}