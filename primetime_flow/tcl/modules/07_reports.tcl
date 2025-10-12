#==============================================================================
# Module: Reports
# Description: Report generation utilities
#==============================================================================

namespace eval ::PT::Reports {}

proc ::PT::Reports::generate_qor {} {
    puts "\nGenerating QoR reports..."
    
    set qor_dir "$::CONFIG(REPORT_DIR)/qor"
    file mkdir $qor_dir
    
    ::PT::Utils::safe_exec {
        redirect -file "$qor_dir/qor.rpt" {report_qor}
        redirect -file "$qor_dir/design.rpt" {report_design}
        redirect -file "$qor_dir/hierarchy.rpt" {report_hierarchy}
        redirect -file "$qor_dir/area.rpt" {report_area -hierarchy}
    } "Generating QoR reports"
    
    puts "✓ QoR reports saved to: $qor_dir"
}

proc ::PT::Reports::generate_summary {} {
    set summary_file "$::CONFIG(REPORT_DIR)/summary.txt"
    set fp [open $summary_file "w"]
    
    puts $fp "Analysis Summary"
    puts $fp "================"
    puts $fp "Run: $::CONFIG(RUN_NAME)"
    puts $fp "Design: $::CONFIG(DESIGN_NAME)"
    puts $fp "Date: [clock format [clock seconds]]"
    puts $fp ""
    
    # Timing summary
    if {[catch {
        set setup_wns [get_attribute [get_timing_paths -delay max] slack]
        set hold_wns [get_attribute [get_timing_paths -delay min] slack]
        puts $fp "Timing:"
        puts $fp "  Setup WNS: $setup_wns"
        puts $fp "  Hold WNS: $hold_wns"
    }]} {
        puts $fp "Timing: Not available"
    }
    
    puts $fp ""
    puts $fp "Memory used: [::PT::Utils::measure_memory]"
    
    close $fp
    puts "✓ Summary saved: $summary_file"
}

proc ::PT::Reports::generate_debug_info {} {
    if {!$::CONFIG(DEBUG)} return
    
    set debug_file "$::CONFIG(LOG_DIR)/debug_info.txt"
    set fp [open $debug_file "w"]
    
    puts $fp "Debug Information"
    puts $fp "================="
    puts $fp "PrimeTime version: [get_app_var sh_arch]"
    puts $fp "Libraries: [get_libs]"
    puts $fp "Design: [current_design]"
    puts $fp ""
    puts $fp "Configuration:"
    foreach {key val} [array get ::CONFIG] {
        puts $fp "  $key = $val"
    }
    
    close $fp
}