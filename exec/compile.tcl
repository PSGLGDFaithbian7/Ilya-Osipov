#!/usr/bin/env tclsh
#==============================================================================
# 0. 文件句柄与路径（保持你原样）
#==============================================================================
set outputfile     "./work/script.tcl"
set fileToWrite    [open $outputfile a]   

puts $fileToWrite "\n#============================================================================#"
puts $fileToWrite "#                                Synthesize                                   #"
puts $fileToWrite "#============================================================================#"

puts $fileToWrite {# Prevent assignment statements in the Verilog netlist.}
puts $fileToWrite {set_fix_multiple_port_nets -feedthrough [get_designs *]}
puts $fileToWrite {set_fix_multiple_port_nets -all -buffer_constants [get_designs *]}

puts $fileToWrite "\n# Power optimization settings"
puts $fileToWrite {set_leakage_optimization true}
puts $fileToWrite {set_dynamic_optimization true}

puts $fileToWrite "\n# Area constraint (0 means optimize for timing)"
puts $fileToWrite {set_max_area 0}
puts $fileToWrite {set_max_area_percentage 0}
puts $fileToWrite "\n# Structuring and mapping effort"

puts $fileToWrite {set_structure true -timing true -boolean false}

puts $fileToWrite {# Set clock gating style BEFORE compile (library likely lacks ICG cells)}
puts $fileToWrite {# Use latch-based gating to avoid PWR-191}
puts $fileToWrite {set_clock_gating_style -sequential_cell latch}

puts $fileToWrite {
# Final check before compiling
if [catch {redirect ../report/report.check_beforecompile {check_design}} cd_status] {
    puts "Check Design Error before compile: $cd_status"
    exit
} else {
    puts "Check Design Pass before compile!"
}
}


# --- Section 3: Compile ---
puts $fileToWrite "\n# ---------------- Compile (DW enabled + capture log) ----------------"
puts $fileToWrite {
set DATE [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]

# Audit current library settings
redirect -file ../report/${top_module}_${DATE}_env.libs.rpt {
  echo "synthetic_library = [get_app_var synthetic_library]"
  echo "link_library      = [get_app_var link_library]"
  echo "search_path       = [get_app_var search_path]"
}

# Real compile with robust error capture
set rc [catch {
  redirect -file ../report/${top_module}_${DATE}_compile_ultra.log {
    compile_ultra -no_autoungroup -no_seq_output_inversion -gate_clock
  }
} comp_err]
if {$rc} {
  puts "Compile failed! See compile log. Error: $comp_err"
  exit 1
}

# Post-compile sanity checks
redirect -file ../report/${top_module}_${DATE}_post_checks.rpt {
  check_design
  check_timing
}
}

# --- Section 4: Post-Compile Settings ---
puts $fileToWrite "\n# ---------------- Conservative pre-CTS IO transitions ----------------"
puts $fileToWrite {
# Apply input transition only to non-ideal inputs (exclude clk/rst_n)
set nonideal_inputs [remove_from_collection [all_inputs] [list [get_ports clk] [get_ports rst_n]]]
if {[sizeof_collection $nonideal_inputs] > 0} {
  set_input_transition 0.5 $nonideal_inputs
}

# Optional frequency scaling clock
if {![info exists CLOCK_PERIOD]} { set CLOCK_PERIOD 10.0 }
set clks [get_clocks *]
if {[sizeof_collection $clks] == 0} {
  puts "No clocks found! Cannot apply frequency scaling."
} else {
  # Create a scaled clock with a new name to avoid overriding existing one
  create_clock -name clk_scaled -period [expr ${CLOCK_PERIOD} * 0.85] [get_ports [lindex $clks 0]]
}
}

# --- Section 5: Enhanced Power Analysis ---
puts $fileToWrite "\n# ===================== Power Analysis — Enhanced ====================="
puts $fileToWrite {
# If the POWER_PROFILE environment variable is set to "basic", revert to basic analysis; otherwise, perform enhanced analysis.
set use_enhanced 1
if {[info exists ::env(POWER_PROFILE)]} {
  if {$::env(POWER_PROFILE) eq "basic"} { set use_enhanced 0 }
}

set ACTIVITY_DIR          ../activity
set SAIF_FILE             "$ACTIVITY_DIR/${top_module}.saif"
set VCD_FILE              "$ACTIVITY_DIR/${top_module}.vcd"
set TOP_INSTANCE          $top_module

# Default to high effort
set POWER_ANALYSIS_EFFORT   high
# Initial unit is toggles per cycle; switch to per second if SAIF/VCD is read
set_power_analysis_options -toggle_rate_unit toggles_per_cycle

# Heuristic values (used only when no SAIF/VCD is available)
set DATA_STATIC_PROB        0.5
set DATA_TOGGLE_PER_CYCLE   0.20
set RST_TOGGLE_PER_CYCLE    0.01
set QPIN_TOGGLE_PER_CYCLE   0.10
set OUT_TOGGLE_PER_CYCLE    0.10

proc _file_exists {f} {expr {[string length $f]>0 && [file exists $f]}}

# Uniformly reset activity information
reset_switching_activity [current_design]

if {$use_enhanced} {
  if { [_file_exists $SAIF_FILE] || [_file_exists $VCD_FILE] } {
      # Read external waveform: switch unit to toggles per second
      set_power_analysis_options -toggle_rate_unit toggles_per_second
      if { [_file_exists $SAIF_FILE] } {
          read_saif -input $SAIF_FILE -instance $TOP_INSTANCE -verbose
      } elseif { [_file_exists $VCD_FILE] } {
          set _tmp ../report/_vcd2saif.saif
          if { ![catch {sh vcd2saif -input $VCD_FILE -output $_tmp -instance $TOP_INSTANCE}] } {
              read_saif -input $_tmp -instance $TOP_INSTANCE -verbose
              file delete $_tmp
          } else {
              puts "WARN: vcd2saif failed; fall back to vectorless heuristics"
          }
      }
  } else {
      puts "INFO: No SAIF/VCD found — using vectorless heuristics"
      # Clock: 1 toggle/cycle
      set clk_ports [get_attribute [get_clocks *] sources]
      if {[sizeof_collection $clk_ports] > 0} {
          set_switching_activity -static_probability 0.5 -toggle_rate 1.0 $clk_ports
      }
      # Reset: very low toggle rate
      if {[sizeof_collection [get_ports rst_n]] > 0} {
          set_switching_activity -static_probability 1.0 -toggle_rate $RST_TOGGLE_PER_CYCLE [get_ports rst_n]
      }
      # Data inputs
      set data_in [remove_from_collection [all_inputs] [list $clk_ports [get_ports rst_n]]]
      if {[sizeof_collection $data_in] > 0} {
          set_switching_activity -static_probability $DATA_STATIC_PROB -toggle_rate $DATA_TOGGLE_PER_CYCLE $data_in
      }
      # Register Q pins
      set qpins [all_registers -q_pins]
      if {[sizeof_collection $qpins] > 0} {
          set_switching_activity -static_probability 0.5 -toggle_rate $QPIN_TOGGLE_PER_CYCLE $qpins
      }
      # Top-level outputs
      if {[sizeof_collection [all_outputs]] > 0} {
          set_switching_activity -static_probability 0.5 -toggle_rate $OUT_TOGGLE_PER_CYCLE [all_outputs]
      }
  }

  # High-effort power analysis and reporting
  redirect -file ../report/${top_module}_${DATE}_power_summary.rpt {
      report_power -hier -analysis_effort $POWER_ANALYSIS_EFFORT -nosplit
  }
  catch { redirect -file ../report/${top_module}_${DATE}_switching_activity_summary.rpt {
      report_switching_activity -hierarchy -summary -nosplit
  }}
} else {
  # BASIC: Run only a basic report for compatibility
  redirect -file ../report/${top_module}_${DATE}_power_summary_basic.rpt {
      report_power -hier -analysis_effort low -nosplit
  }
}
}
puts $fileToWrite "\n# =================== End of Enhanced Power Analysis ==================="
puts $fileToWrite "\nputs \"\nINFO: Synthesis and Power Analysis Script finished.\""
puts "Successfully generated '$fileToWrite'."


flush $fileToWrite
close $fileToWrite
puts "Conservative Pre-CTS script generated (no file output section)."