#==============================================================================
# Module: Analysis Modes
# Description: Special analysis modes (histogram, rail, etc.)
#==============================================================================

namespace eval ::PT::Modes {}

proc ::PT::Modes::histogram_analysis {} {
    if {!$::CONFIG(REPORT_HISTOGRAM)} return
    
    puts "\nGenerating path histogram..."
    
    set rpt_dir "$::CONFIG(REPORT_DIR)/timing"
    
    ::PT::Utils::safe_exec {
        redirect -file "$rpt_dir/histogram_setup.rpt" {
            report_timing -delay max -histogram
        }
        redirect -file "$rpt_dir/histogram_hold.rpt" {
            report_timing -delay min -histogram
        }
    } "Generating timing histograms"
}

proc ::PT::Modes::rail_analysis {} {
    puts "\nChecking rail analysis..."
    
    if {[catch {set rails [get_supply_nets -quiet]} err]} {
        puts "Rail analysis not available"
        return
    }
    
    if {[sizeof_collection $rails] > 0} {
        set rpt_dir "$::CONFIG(REPORT_DIR)/power"
        
        ::PT::Utils::safe_exec {
            redirect -file "$rpt_dir/rail_analysis.rpt" {
                report_supply_net
            }
        } "Generating rail analysis"
    }
}

proc ::PT::Modes::quick_mode {} {
    if {![info exists ::CONFIG(QUICK)] || !$::CONFIG(QUICK)} return
    
    puts "INFO: Quick mode enabled - generating minimal reports"
    
    # Override report generation
    set ::CONFIG(REPORT_DETAILED) 0
    set ::CONFIG(REPORT_HISTOGRAM) 0
}

proc ::PT::Modes::netlist_format_check {} {
    set netlist $::CONFIG(NETLIST)
    
    # Check for SystemVerilog constructs
    if {[file extension $netlist] in {.v .sv}} {
        set fp [open $netlist r]
        set content [read $fp]
        close $fp
        
        set sv_keywords {interface modport package class endclass}
        foreach keyword $sv_keywords {
            if {[regexp "\\b$keyword\\b" $content]} {
                puts "WARNING: SystemVerilog keyword '$keyword' detected"
                puts "         Consider using compiled .db format for better support"
            }
        }
    }
}