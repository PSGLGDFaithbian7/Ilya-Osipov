#!/usr/bin/env tclsh
# =============================================================================
# Main Synthesis Script - Preserving All Original Features
# Direct Execution Mode with Full Multi-Clock/Reset/Library Support
# =============================================================================

set SCRIPT_DIR [file dirname [info script]]
set PROJECT_ROOT [file dirname $SCRIPT_DIR]

# Load all libraries
source [file join $SCRIPT_DIR lib utils.tcl]
source [file join $SCRIPT_DIR lib config_parser.tcl]
source [file join $SCRIPT_DIR lib rtl_finder.tcl]
source [file join $SCRIPT_DIR lib constraint_gen.tcl]
source [file join $SCRIPT_DIR lib power_analysis.tcl]
source [file join $SCRIPT_DIR lib report_gen.tcl]

# Load configuration
if {![info exists ::env(CONFIG_FILE)]} {
    set ::env(CONFIG_FILE) "config/project_config.yaml"
}
set config [config::load $::env(CONFIG_FILE)]

# Get timestamp and top module
set DATE [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
set top_module [dict get $config project top_module]

utils::print_banner "Industrial Grade Synthesis Flow"
puts "Top Module: $top_module"
puts "Timestamp: $DATE"
puts "Configuration: $::env(CONFIG_FILE)"

# =============================================================================
# 1. Setup Design Compiler Environment
# =============================================================================
utils::print_section "Setting up Design Compiler"

# Clean and setup
remove_design -all
set_host_options -max_cores [dict get $config synthesis advanced max_cores]
set_svf "../output/${top_module}_${DATE}.svf"

# Error handling
set_app_var sh_continue_on_error false
set_app_var synlib_wait_for_design_license [list "DesignWare-Foundation"]

# Utility procedures for DC
proc cmd_exists {name} { expr {[llength [info commands $name]] > 0} }
proc if_cmd {name args} {
    if {[cmd_exists $name]} { uplevel 1 [list $name] $args }
}

# =============================================================================
# 2. Configure Multiple Libraries Support
# =============================================================================
utils::print_section "Configuring Libraries"

# Search paths
set search_paths [dict get $config library search_paths]
set expanded_paths {}
foreach path $search_paths {
    lappend expanded_paths [utils::expand_vars $path]
}
set_app_var search_path [join $expanded_paths " "]
puts "INFO: Search paths configured: [llength $expanded_paths] paths"

# Target libraries - MULTIPLE SUPPORT
set target_libs [dict get $config library target_libraries]
set_app_var target_library [join $target_libs " "]
puts "INFO: Target libraries: $target_libs"

# Link libraries - MULTIPLE SUPPORT
set link_libs [dict get $config library link_libraries]
set synthetic_libs [dict get $config library synthetic_libraries]
set symbol_libs [dict get $config library symbol_libraries {}]

# Combine all libraries for link_library
set all_link_libs [concat $target_libs $link_libs $synthetic_libs]
set_app_var link_library "* [join $all_link_libs { }]"
puts "INFO: Link libraries: [llength $all_link_libs] libraries"

# Synthetic library
if {[llength $synthetic_libs] > 0} {
    set_app_var synthetic_library [join $synthetic_libs " "]
    puts "INFO: Synthetic libraries: $synthetic_libs"
}

# Symbol library
if {[llength $symbol_libs] > 0} {
    set_app_var symbol_library [join $symbol_libs " "]
    puts "INFO: Symbol libraries: $symbol_libs"
}

# =============================================================================
# 3. Read RTL Design - Using Original Recursive Finder
# =============================================================================
utils::print_section "Reading RTL Design"

# Define work library
define_design_lib WORK -path ./work

# Find all RTL files using the ORIGINAL recursive finder
set rtl_dirs [dict get $config rtl search_dirs]
set file_patterns [dict get $config rtl file_extensions]
set rtl_files [rtl::find_all_files $rtl_dirs $file_patterns]
puts "INFO: Found [llength $rtl_files] RTL files"

# Include directories
set include_dirs [dict get $config rtl include_dirs]
set include_opts ""
foreach dir $include_dirs {
    append include_opts "+incdir+[utils::expand_vars $dir] "
}

# Defines
set defines [dict get $config rtl defines]
set define_opts ""
foreach def $defines {
    append define_opts "-define $def "
}

# Analyze all files
foreach file $rtl_files {
    set filename [file tail $file]
    if {[regexp {\.sv$|\.v$} $file]} {
        puts "Analyzing Verilog: $filename"
        if {$include_opts ne "" || $define_opts ne ""} {
            eval analyze -format sverilog -vcs \"$include_opts\" $define_opts {$file}
        } else {
            analyze -format sverilog $file
        }
    } elseif {[regexp {\.vhd$|\.vhdl$} $file]} {
        puts "Analyzing VHDL: $filename"
        analyze -format vhdl $file
    }
}

# Elaborate and link
elaborate $top_module
current_design $top_module
link
uniquify -force

# Design check
redirect "../report/${DATE}/initial_check_design.rpt" {
    check_design
}

# Save elaborated design
write_file -format ddc -hierarchy -output "../output/${DATE}_${top_module}_elaborated.ddc"

# =============================================================================
# 4. Apply Constraints - MULTIPLE CLOCKS/RESETS/IOs SUPPORT
# =============================================================================
utils::print_section "Applying Timing & Environmental Constraints"

# Apply multiple clock constraints
set clock_info [constraint::apply_clock_constraints $config]
set clock_names [lindex $clock_info 0]
set clock_ports [lindex $clock_info 1]
puts "INFO: Configured [llength $clock_names] clocks: $clock_names"

# Apply multiple reset constraints
set reset_ports [constraint::apply_reset_constraints $config]
puts "INFO: Configured [llength $reset_ports] resets: $reset_ports"

# Apply multiple IO constraints
constraint::apply_io_constraints $config $clock_names $clock_ports $reset_ports

# Apply environmental constraints
constraint::apply_environmental_constraints $config

# =============================================================================
# 5. Configure Synthesis Options
# =============================================================================
utils::print_section "Configuring Synthesis Options"

# Netlist naming
set_app_var verilogout_no_tri true
set_app_var verilogout_show_unconnected_pins true
set_app_var bus_naming_style {%s[%d]}
define_name_rules MY_RULES -allowed "A-Za-z0-9_" -first_restricted "0-9_" -max_length 256 -case_insensitive
change_names -rules MY_RULES -hierarchy

# Fix multiple port nets
set_fix_multiple_port_nets -feedthrough [get_designs *]
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]

# Power optimization
set power_opts [dict get $config synthesis power]
set_leakage_optimization [dict get $power_opts leakage_optimization]
set_dynamic_optimization [dict get $power_opts dynamic_optimization]

# Area constraint
set area_opts [dict get $config synthesis area]
set_max_area [dict get $area_opts max_area]

# Structure options
set opt_opts [dict get $config synthesis optimization]
set_structure true -timing [dict get $opt_opts structure_timing] -boolean [dict get $opt_opts structure_boolean]

# Clock gating
set clock_gating_style [dict get $power_opts clock_gating_style]
if {$clock_gating_style ne "none"} {
    set_clock_gating_style -sequential_cell $clock_gating_style
}

# Setup path groups
constraint::setup_path_groups $clock_names

# =============================================================================
# 6. Pre-Synthesis Checks
# =============================================================================
utils::print_section "Pre-Synthesis Checks"

redirect "../report/${DATE}/pre_synthesis_checks.rpt" {
    check_design
    check_timing
}

# =============================================================================
# 7. Run Synthesis
# =============================================================================
utils::print_section "Running Synthesis"

set compile_strategy [dict get $config synthesis compile_strategy]
set compile_log "../report/${DATE}/${top_module}_compile.log"

# Build compile command
if {$compile_strategy eq "ultra"} {
    set compile_cmd "compile_ultra"
    set compile_opts {}
    
    if {![dict get $opt_opts auto_ungroup]} {
        lappend compile_opts "-no_autoungroup"
    }
    if {![dict get $opt_opts boundary_optimization]} {
        lappend compile_opts "-no_boundary_optimization"
    }
    if {![dict get $opt_opts sequential_output_inversion]} {
        lappend compile_opts "-no_seq_output_inversion"
    }
    if {$clock_gating_style ne "none"} {
        lappend compile_opts "-gate_clock"
    }
} else {
    set compile_cmd "compile"
    set compile_opts [list "-map_effort" $compile_strategy]
}

puts "INFO: Compile command: $compile_cmd $compile_opts"

# Execute synthesis
set rc [catch {
    redirect $compile_log {
        eval $compile_cmd $compile_opts
    }
} comp_err]

if {$rc} {
    puts "ERROR: Compile failed! Error: $comp_err"
    puts "Check log: $compile_log"
    exit 1
}

puts "INFO: Synthesis completed successfully"

# Post-compile checks
redirect "../report/${DATE}/post_compile_checks.rpt" {
    check_design
    check_timing
}

# =============================================================================
# 8. Post-Synthesis Optimization
# =============================================================================
utils::print_section "Post-Synthesis Optimization"

# Apply conservative input transition
set all_clk_rst_ports [concat $clock_ports $reset_ports]
set nonideal_inputs [remove_from_collection [all_inputs] [get_ports $all_clk_rst_ports]]
if {[sizeof_collection $nonideal_inputs] > 0} {
    set_input_transition 0.5 $nonideal_inputs
}

# =============================================================================
# 9. Power Analysis (Enhanced)
# =============================================================================
utils::print_section "Power Analysis"

power::perform_analysis $config $top_module $DATE

# =============================================================================
# 10. Generate All Reports
# =============================================================================
utils::print_section "Generating Comprehensive Reports"

report::generate_all $config $top_module $DATE

# =============================================================================
# 11. Write Output Files
# =============================================================================
utils::print_section "Writing Output Files"

set output_root "../output/$DATE"
file mkdir "$output_root/netlist"
file mkdir "$output_root/constraints"
file mkdir "$output_root/parasitics"

# Apply final naming rules
change_names -rules sverilog -hierarchy

# Write netlist
write -format verilog -hierarchy -output "$output_root/netlist/${top_module}.v"
write -format ddc -hierarchy -output "$output_root/netlist/${top_module}.ddc"

# Write constraints
write_sdc "$output_root/constraints/${top_module}.sdc"
write_sdf "$output_root/constraints/${top_module}.sdf"

# Write parasitics
set rc_out "$output_root/parasitics/${top_module}.rc"
set wp_err [catch {write_parasitics -format reduced -output $rc_out}]
if {$wp_err} {
    puts "WARN: write_parasitics reduced failed"
    set wp_err2 [catch {write_parasitics -format distributed -output $rc_out}]
    if {$wp_err2} {
        puts "ERROR: write_parasitics failed"
    } else {
        puts "INFO: Parasitics written in distributed format: $rc_out"
    }
} else {
    puts "INFO: Parasitics written in reduced format: $rc_out"
}

# Close SVF
set_svf -off

# =============================================================================
# 12. Generate QoR Summary
# =============================================================================
utils::print_section "QoR Summary Generation"

report::generate_qor_summary $top_module $DATE

# =============================================================================
# Final Message
# =============================================================================
utils::print_banner "Synthesis Flow Completed Successfully"
puts "Top Module: $top_module"
puts "Timestamp: $DATE"
puts "Reports: ../report/$DATE/"
puts "Outputs: ../output/$DATE/"
puts ""
puts "Key Outputs:"
puts "  Netlist: ../output/$DATE/netlist/${top_module}.v"
puts "  SDC:     ../output/$DATE/constraints/${top_module}.sdc"
puts "  Reports: ../report/$DATE/analysis/qor_analysis.html"