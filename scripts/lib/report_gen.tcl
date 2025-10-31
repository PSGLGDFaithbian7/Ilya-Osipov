#!/usr/bin/env tclsh
# =============================================================================
# Report Generator Module - Comprehensive Reporting
# =============================================================================

namespace eval ::report {
    
    # Generate all reports
    proc generate_all {config top_module date} {
        puts "######## GENERATING COMPREHENSIVE REPORTS ########"
        
        # Get report configuration
        set report_config [dict get $config reports]
        set categories [dict get $report_config categories]
        
        # Create report directories
        set report_root "../report/$date"
        create_report_directories $report_root
        
        # Generate reports by category
        if {[dict get $categories timing enabled]} {
            generate_timing_reports $report_root $top_module $categories
        }
        
        if {[dict get $categories area enabled]} {
            generate_area_reports $report_root $top_module $categories
        }
        
        if {[dict get $categories power enabled]} {
            generate_power_reports_detailed $report_root $top_module $categories
        }
        
        if {[dict get $categories clock enabled]} {
            generate_clock_reports $report_root $top_module $categories
        }
        
        if {[dict get $categories qor enabled]} {
            generate_qor_reports $report_root $top_module
        }
        
        if {[dict get $categories design_checks enabled]} {
            generate_check_reports $report_root $top_module
        }
        
        puts "INFO: All reports generated in $report_root"
    }
    
    # Create report directory structure
    proc create_report_directories {report_root} {
        foreach dir {timing area power clock qor checks analysis} {
            file mkdir "$report_root/$dir"
        }
    }
    
    # Generate timing reports
    proc generate_timing_reports {report_root top_module config} {
        puts "INFO: Generating timing reports..."
        
        set timing_dir "$report_root/timing"
        set timing_config [dict get $config timing]
        set max_paths [dict get $timing_config paths]
        
        # Setup timing report
        redirect "$timing_dir/${top_module}_timing_setup.rpt" {
            report_timing \
                -delay_type max \
                -max_paths $max_paths \
                -path full_clock_expanded \
                -nets \
                -transition_time \
                -capacitance \
                -sort_by slack \
                -nosplit
        }
        
        # Hold timing report
        redirect "$timing_dir/${top_module}_timing_hold.rpt" {
            report_timing \
                -delay_type min \
                -max_paths $max_paths \
                -path full_clock_expanded \
                -nets \
                -transition_time \
                -capacitance \
                -sort_by slack \
                -nosplit
        }
        
        # Recovery and removal (if applicable)
        catch {
            redirect "$timing_dir/${top_module}_timing_recovery.rpt" {
                report_timing -delay_type max -max_paths 10 -recovery -nosplit
            }
            redirect "$timing_dir/${top_module}_timing_removal.rpt" {
                report_timing -delay_type min -max_paths 10 -removal -nosplit
            }
        }
        
        # Timing summary
        redirect "$timing_dir/${top_module}_timing_summary.rpt" {
            report_timing_summary -nosplit
        }
        
        # Constraint violations
        redirect "$timing_dir/${top_module}_constraint_violations.rpt" {
            report_constraint -all_violators -verbose -nosplit
        }
        
        # Path groups
        redirect "$timing_dir/${top_module}_path_groups.rpt" {
            report_path_group -nosplit
        }
        
        # Clock interactions
        redirect "$timing_dir/${top_module}_clock_interactions.rpt" {
            report_clock_interaction -nosplit
        }
        
        # Timing requirements
        redirect "$timing_dir/${top_module}_timing_requirements.rpt" {
            report_timing_requirements -nosplit
        }
    }
    
    # Generate area reports
    proc generate_area_reports {report_root top_module config} {
        puts "INFO: Generating area reports..."
        
        set area_dir "$report_root/area"
        set area_config [dict get $config area]
        
        # Hierarchical area report
        if {[dict get $area_config hierarchy]} {
            redirect "$area_dir/${top_module}_area_hierarchy.rpt" {
                report_area -hierarchy -nosplit
            }
        }
        
        # Basic area report
        redirect "$area_dir/${top_module}_area.rpt" {
            report_area -nosplit
        }
        
        # Area by cell type
        redirect "$area_dir/${top_module}_area_by_cell_type.rpt" {
            report_area -designware -nosplit
        }
        
        # Cell count
        redirect "$area_dir/${top_module}_cell_count.rpt" {
            report_cell_count -hierarchy -nosplit
        }
        
        # Reference report
        redirect "$area_dir/${top_module}_references.rpt" {
            report_reference -hierarchy -nosplit
        }
        
        # Resources report (if using DesignWare)
        catch {
            redirect "$area_dir/${top_module}_resources.rpt" {
                report_resources -hierarchy -nosplit
            }
        }
    }
    
    # Generate detailed power reports
    proc generate_power_reports_detailed {report_root top_module config} {
        puts "INFO: Generating power reports..."
        
        set power_dir "$report_root/power"
        set power_config [dict get $config power]
        
        # These are generated by power_analysis.tcl, but we can add more here
        
        # Power optimization report
        redirect "$power_dir/${top_module}_power_optimization.rpt" {
            report_power_optimization -nosplit
        }
        
        # Leakage power by cell
        catch {
            redirect "$power_dir/${top_module}_leakage_by_cell.rpt" {
                report_power -cell -leakage -nosplit
            }
        }
        
        # Power by hierarchy level
        redirect "$power_dir/${top_module}_power_by_hierarchy.rpt" {
            report_power -hierarchy -levels 3 -nosplit
        }
    }
    
    # Generate clock reports
    proc generate_clock_reports {report_root top_module config} {
        puts "INFO: Generating clock reports..."
        
        set clock_dir "$report_root/clock"
        set clock_config [dict get $config clock]
        
        # Clock report
        redirect "$clock_dir/${top_module}_clocks.rpt" {
            report_clocks -attributes -nosplit
        }
        
        # Clock tree
        redirect "$clock_dir/${top_module}_clock_tree.rpt" {
            report_clock_tree -summary -nosplit
        }
        
        # Clock skew
        redirect "$clock_dir/${top_module}_clock_skew.rpt" {
            report_clock_timing -type skew -significant_digits 3 -nosplit
        }
        
        # Clock gating
        if {[dict get $clock_config gating_report]} {
            redirect "$clock_dir/${top_module}_clock_gating.rpt" {
                report_clock_gating -multi_stage -verbose -nosplit
            }
            
            redirect "$clock_dir/${top_module}_clock_gating_check.rpt" {
                report_clock_gating_check -nosplit
            }
        }
        
        # Clock transition
        redirect "$clock_dir/${top_module}_clock_transition.rpt" {
            report_clock_timing -type transition -nosplit
        }
        
        # Clock uncertainty
        redirect "$clock_dir/${top_module}_clock_uncertainty.rpt" {
            report_clock_timing -type uncertainty -nosplit
        }
    }
    
    # Generate QoR reports
    proc generate_qor_reports {report_root top_module} {
        puts "INFO: Generating QoR reports..."
        
        set qor_dir "$report_root/qor"
        
        # Main QoR report
        redirect "$qor_dir/${top_module}_qor.rpt" {
            report_qor -nosplit
        }
        
        # QoR histogram
        redirect "$qor_dir/${top_module}_qor_histogram.rpt" {
            report_qor -histogram -nosplit
        }
        
        # Design summary
        redirect "$qor_dir/${top_module}_design_summary.rpt" {
            print_design_summary
        }
        
        # Utilization
        redirect "$qor_dir/${top_module}_utilization.rpt" {
            report_utilization -nosplit
        }
    }
    
    # Generate design check reports
    proc generate_check_reports {report_root top_module} {
        puts "INFO: Generating design check reports..."
        
        set check_dir "$report_root/checks"
        
        # Design check
        redirect "$check_dir/${top_module}_check_design.rpt" {
            check_design -multiple_designs
        }
        
        # Timing check
        redirect "$check_dir/${top_module}_check_timing.rpt" {
            check_timing -verbose
        }
        
        # Multi-voltage check
        catch {
            redirect "$check_dir/${top_module}_check_mv.rpt" {
                check_mv_design -verbose
            }
        }
        
        # Test check (if DFT is enabled)
        catch {
            redirect "$check_dir/${top_module}_check_test.rpt" {
                check_test
            }
        }
        
        # Linting checks
        redirect "$check_dir/${top_module}_lint.rpt" {
            check_design -no_warnings
        }
    }
    
    # Generate QoR summary for display
    proc generate_qor_summary {top_module date} {
        puts "INFO: Generating QoR summary..."
        
        set qor_file "../report/$date/qor/qor_summary.txt"
        file mkdir [file dirname $qor_file]
        set fh [open $qor_file w]
        
        # Get key metrics
        set setup_slack "N/A"
        set hold_slack "N/A"
        set area "N/A"
        set power "N/A"
        
        # Try to extract setup slack
        catch {
            set paths [get_timing_paths -delay_type max -max_paths 1]
            if {[sizeof_collection $paths] > 0} {
                set setup_slack [get_attribute $paths slack]
            }
        }
        
        # Try to extract hold slack
        catch {
            set paths [get_timing_paths -delay_type min -max_paths 1]
            if {[sizeof_collection $paths] > 0} {
                set hold_slack [get_attribute $paths slack]
            }
        }
        
        # Try to extract area
        catch {
            set area [get_attribute [current_design] area]
        }
        
        # Write summary
        puts $fh "QoR Metrics:"
        puts $fh "  Setup Slack: $setup_slack ns"
        puts $fh "  Hold Slack:  $hold_slack ns"
        puts $fh "  Total Area:  $area um²"
        puts $fh "  Frequency:   [expr {1000.0 / [get_attribute [get_clocks] period]}] MHz"
        
        close $fh
        
        # Also print to console
        puts ""
        puts "========== QoR Summary =========="
        puts "  Setup Slack: $setup_slack ns"
        puts "  Hold Slack:  $hold_slack ns"
        puts "  Total Area:  $area um²"
        puts "================================="
    }
    
    # Helper procedure to print design summary
    proc print_design_summary {} {
        puts "=========================================="
        puts " Design Summary"
        puts "=========================================="
        
        # Basic info
        puts "Design: [get_attribute [current_design] full_name]"
        puts "Technology: [get_attribute [get_libs *] library]"
        
        # Instance counts
        set total_instances [sizeof_collection [get_cells -hierarchical]]
        set seq_instances [sizeof_collection [all_registers]]
        set comb_instances [expr {$total_instances - $seq_instances}]
        
        puts ""
        puts "Instance Statistics:"
        puts "  Total instances:        $total_instances"
        puts "  Sequential instances:   $seq_instances"
        puts "  Combinational instances: $comb_instances"
        
        # Port counts
        set input_ports [sizeof_collection [all_inputs]]
        set output_ports [sizeof_collection [all_outputs]]
        set inout_ports [sizeof_collection [all_inouts]]
        
        puts ""
        puts "Port Statistics:"
        puts "  Input ports:  $input_ports"
        puts "  Output ports: $output_ports"
        puts "  InOut ports:  $inout_ports"
        
        # Net counts
        set total_nets [sizeof_collection [get_nets -hierarchical]]
        puts ""
        puts "Net Statistics:"
        puts "  Total nets: $total_nets"
        
        puts "=========================================="
    }
}