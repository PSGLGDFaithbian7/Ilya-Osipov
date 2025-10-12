#==============================================================================
# Module: Power Analysis
# Description: Power analysis execution
#==============================================================================

namespace eval ::PT::Power {}

proc ::PT::Power::setup {} {
    puts "\nConfiguring power analysis..."
    
    ::PT::Utils::safe_exec {
        set_app_var power_enable_analysis true
        set_app_var power_analysis_mode averaged
        set_app_var power_clock_network_include_register_clock_pin_power false
        set_app_var power_analysis_effort high
    } "Power configuration"
}

proc ::PT::Power::read_activity {} {
    puts "\nReading switching activity..."
    
    set loaded 0
    
    # Try VCD
    if {$::CONFIG(ACTIVITY_PRIORITY) eq "VCD_FIRST" && [file exists $::CONFIG(VCD_FILE)]} {
        if {![catch {
            ::PT::Utils::safe_exec {
                read_vcd $::CONFIG(VCD_FILE) -strip_path $::CONFIG(DESIGN_NAME)
            } "Reading VCD"
        }]} {
            set loaded 1
            puts "✓ VCD loaded"
        }
    }
    
    # Try SAIF
    if {!$loaded && [file exists $::CONFIG(SAIF_FILE)]} {
        if {![catch {
            ::PT::Utils::safe_exec {
                read_saif $::CONFIG(SAIF_FILE) -strip_path $::CONFIG(DESIGN_NAME)
            } "Reading SAIF"
        }]} {
            set loaded 1
            puts "✓ SAIF loaded"
        }
    }
    
    # Default activity
    if {!$loaded} {
        puts "Using default switching activity"
        ::PT::Utils::safe_exec {
            set_switching_activity -static_probability 0.5 -toggle_rate 0.1 [all_inputs]
            set_switching_activity -static_probability 0.5 -toggle_rate 0.05 [all_registers]
        } "Setting default activity"
    }
}

proc ::PT::Power::analyze {} {
    ::PT::print_header "Power Analysis"
    
    setup
    read_activity
    
    puts "\nCalculating power..."
    
    ::PT::Utils::safe_exec {
        update_power
    } "Updating power"
    
    # Get summary
    set power_summary [report_power -nosplit]
    puts "\nPower Summary:"
    puts $power_summary
    
    ::PT::Utils::checkpoint "power_complete"
}

proc ::PT::Power::generate_reports {} {
    puts "\nGenerating power reports..."
    
    set rpt_dir "$::CONFIG(REPORT_DIR)/power"
    file mkdir $rpt_dir
    
    set reports {
        {summary.rpt           "report_power -hierarchy"}
        {detailed.rpt          "report_power -verbose -cell_power -net_power"}
        {hierarchy.rpt         "report_power -hierarchy -levels 5"}
        {clock_power.rpt       "report_power -clock_network"}
        {switching.rpt         "report_switching_activity -list_not_annotated"}
    }
    
    foreach {file cmd} $reports {
        ::PT::Utils::safe_exec {
            redirect -file "$rpt_dir/$file" $cmd
        } "Generating $file"
    }
    
    puts "✓ Reports saved to: $rpt_dir"
}