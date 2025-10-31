#!/usr/bin/env tclsh
# =============================================================================
# Power Analysis Module - Enhanced Version
# Preserving original power analysis logic with improvements
# =============================================================================

namespace eval ::power {
    
    # Main power analysis function
    proc perform_analysis {config top_module date} {
        puts "######## POWER ANALYSIS ########"
        
        # Get power analysis configuration
        set power_config [dict get $config power_analysis]
        set method [dict get $power_config method]
        set effort [dict get $power_config analysis effort]
        
        # Reset switching activity
        catch {reset_switching_activity [current_design]}
        
        # Choose analysis method
        switch $method {
            "saif" {
                analyze_with_saif $power_config $top_module $date
            }
            "vcd" {
                analyze_with_vcd $power_config $top_module $date
            }
            "vectorless" {
                analyze_vectorless $power_config $top_module $date
            }
            default {
                puts "INFO: Using default vectorless analysis"
                analyze_vectorless $power_config $top_module $date
            }
        }
        
        # Generate power reports
        generate_power_reports $top_module $date $effort
        
        puts "INFO: Power analysis completed"
    }
    
    # Vectorless power analysis (most common)
    proc analyze_vectorless {power_config top_module date} {
        puts "INFO: Performing vectorless power analysis"
        
        # Get vectorless parameters
        set vectorless [dict get $power_config vectorless]
        set clk_toggle [dict get $vectorless clock_toggle_rate]
        set rst_toggle [dict get $vectorless reset_toggle_rate]
        set data_toggle [dict get $vectorless data_toggle_rate]
        set reg_toggle [dict get $vectorless register_toggle_rate]
        set out_toggle [dict get $vectorless output_toggle_rate]
        set static_prob [dict get $vectorless static_probability]
        
        # Set power analysis mode
        catch {set_power_analysis_options -toggle_rate_unit toggles_per_cycle}
        
        # 1. Clock ports - highest toggle rate
        set clk_ports [get_ports -filter "direction==in" [get_attribute [get_clocks *] sources]]
        if {[sizeof_collection $clk_ports] > 0} {
            set_switching_activity -static_probability 0.5 -toggle_rate $clk_toggle $clk_ports
            puts "  Set clock toggle rate: $clk_toggle"
        }
        
        # 2. Reset ports - very low toggle
        set reset_ports [get_ports -quiet rst_n]
        if {[sizeof_collection $reset_ports] == 0} {
            set reset_ports [get_ports -quiet {*rst* *RST*}]
        }
        if {[sizeof_collection $reset_ports] > 0} {
            set_switching_activity -static_probability 1.0 -toggle_rate $rst_toggle $reset_ports
            puts "  Set reset toggle rate: $rst_toggle"
        }
        
        # 3. Data inputs
        set data_inputs [remove_from_collection [all_inputs] [list $clk_ports $reset_ports]]
        if {[sizeof_collection $data_inputs] > 0} {
            set_switching_activity -static_probability $static_prob -toggle_rate $data_toggle $data_inputs
            puts "  Set data input toggle rate: $data_toggle"
        }
        
        # 4. Register outputs
        set reg_outputs [get_pins -quiet -of_objects [all_registers] -filter "direction==out"]
        if {[sizeof_collection $reg_outputs] > 0} {
            set_switching_activity -static_probability $static_prob -toggle_rate $reg_toggle $reg_outputs
            puts "  Set register toggle rate: $reg_toggle"
        }
        
        # 5. Primary outputs
        if {[sizeof_collection [all_outputs]] > 0} {
            set_switching_activity -static_probability $static_prob -toggle_rate $out_toggle [all_outputs]
            puts "  Set output toggle rate: $out_toggle"
        }
    }
    
    # SAIF-based power analysis
    proc analyze_with_saif {power_config top_module date} {
        puts "INFO: Attempting SAIF-based power analysis"
        
        # Check for SAIF file
        set activity_files [dict get $power_config activity_files]
        set saif_file [dict get $activity_files saif]
        set saif_file [string map "\${top_module} $top_module" $saif_file]
        
        if {[file exists $saif_file]} {
            puts "  Found SAIF file: $saif_file"
            
            # Switch to time-based toggle rate
            catch {set_power_analysis_options -toggle_rate_unit toggles_per_second}
            
            # Read SAIF
            set read_result [catch {
                read_saif -input $saif_file -instance $top_module -verbose
            } read_error]
            
            if {$read_result} {
                puts "WARN: Failed to read SAIF: $read_error"
                puts "  Falling back to vectorless analysis"
                analyze_vectorless $power_config $top_module $date
            } else {
                puts "  SAIF file successfully loaded"
            }
        } else {
            puts "  SAIF file not found: $saif_file"
            puts "  Using vectorless analysis instead"
            analyze_vectorless $power_config $top_module $date
        }
    }
    
    # VCD-based power analysis
    proc analyze_with_vcd {power_config top_module date} {
        puts "INFO: Attempting VCD-based power analysis"
        
        # Check for VCD file
        set activity_files [dict get $power_config activity_files]
        set vcd_file [dict get $activity_files vcd]
        set vcd_file [string map "\${top_module} $top_module" $vcd_file]
        
        if {[file exists $vcd_file]} {
            puts "  Found VCD file: $vcd_file"
            
            # Try to convert VCD to SAIF
            set temp_saif "../report/_temp_vcd2saif.saif"
            set convert_result [catch {
                sh vcd2saif -input $vcd_file -output $temp_saif -instance $top_module
            } convert_error]
            
            if {$convert_result} {
                puts "WARN: VCD to SAIF conversion failed: $convert_error"
                puts "  Falling back to vectorless analysis"
                analyze_vectorless $power_config $top_module $date
            } else {
                # Read the converted SAIF
                catch {set_power_analysis_options -toggle_rate_unit toggles_per_second}
                read_saif -input $temp_saif -instance $top_module -verbose
                file delete $temp_saif
                puts "  VCD successfully converted and loaded"
            }
        } else {
            puts "  VCD file not found: $vcd_file"
            puts "  Using vectorless analysis instead"
            analyze_vectorless $power_config $top_module $date
        }
    }
    
    # Generate power reports
    proc generate_power_reports {top_module date effort} {
        set report_dir "../report/$date/power"
        file mkdir $report_dir
        
        # Main power report with hierarchy
        redirect "$report_dir/${top_module}_power_hierarchy.rpt" {
            report_power -hierarchy -analysis_effort $effort -nosplit
        }
        
        # Power summary
        redirect "$report_dir/${top_module}_power_summary.rpt" {
            report_power -analysis_effort $effort -verbose -nosplit
        }
        
        # Switching activity report
        catch {
            redirect "$report_dir/${top_module}_switching_activity.rpt" {
                report_switching_activity -hierarchy -summary -nosplit
            }
        }
        
        # Power by clock domain
        catch {
            redirect "$report_dir/${top_module}_power_by_clock.rpt" {
                report_power -cell -analysis_effort $effort -nosplit
            }
        }
        
        # Clock gating report (power related)
        redirect "$report_dir/${top_module}_clock_gating_power.rpt" {
            report_clock_gating -multi_stage -power -nosplit
        }
        
        puts "INFO: Power reports generated in $report_dir"
    }
}