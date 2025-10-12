#==============================================================================
# Module: Static Timing Analysis
# Description: STA execution and reporting
#==============================================================================

namespace eval ::PT::STA {}

proc ::PT::STA::analyze {} {
    ::PT::print_header "Static Timing Analysis"
    
    puts "Running timing analysis..."
    
    ::PT::Utils::safe_exec {
        update_timing -full
    } "Updating timing"
    
    # Get key metrics
    set setup_wns [get_attribute [get_timing_paths -delay max] slack]
    set hold_wns [get_attribute [get_timing_paths -delay min] slack]
    
    puts "\nTiming Summary:"
    puts "  Setup WNS: $setup_wns"
    puts "  Hold WNS: $hold_wns"
    
    if {$setup_wns < 0 || $hold_wns < 0} {
        puts "WARNING: Timing violations detected"
    }
    
    ::PT::Utils::checkpoint "sta_complete"
}

proc ::PT::STA::generate_reports {} {
    puts "\nGenerating STA reports..."
    
    set rpt_dir "$::CONFIG(REPORT_DIR)/timing"
    file mkdir $rpt_dir
    
    # Report list with descriptions
    set reports {
        {summary.rpt          report_qor}
        {timing_summary.rpt   report_timing_summary}
        {setup_paths.rpt      "report_timing -delay max -max_paths 100"}
        {hold_paths.rpt       "report_timing -delay min -max_paths 100"}
        {clock_timing.rpt     "report_clock_timing -type summary"}
        {clock_skew.rpt       "report_clock_timing -type skew"}
        {violations.rpt       "report_constraint -all_violators"}
        {design.rpt           report_design}
        {area.rpt            "report_area -hierarchy"}
    }
    
    foreach {file cmd} $reports {
        ::PT::Utils::safe_exec {
            redirect -file "$rpt_dir/$file" $cmd
        } "Generating $file"
    }
    
    puts "✓ Reports saved to: $rpt_dir"
}

proc ::PT::STA::analyze_critical_paths {} {
    if {!$::CONFIG(DEBUG)} return
    
    puts "\nAnalyzing critical paths..."
    
    set paths [get_timing_paths -delay max -max_paths 10]
    
    foreach_in_collection path $paths {
        set slack [get_attribute $path slack]
        set startpoint [get_attribute $path startpoint]
        set endpoint [get_attribute $path endpoint]
        
        puts "Path: $startpoint -> $endpoint (slack: $slack)"
    }
}