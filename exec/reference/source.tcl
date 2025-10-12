# ================================================================
# DC Script (DW-enabled) — fixed + Power Enhanced
# Top module : Top_multiplier
# Notes :
#   - Fix obsolete/unknown cmds and gating style
#   - Robust compile error handling
#   - Enhanced power analysis (SAIF/VCD first; else vectorless heuristics)
#   - Compatible with DC S-2021.06-SP2
# ================================================================

# ---------------- Clean & Runtime ----------------
remove_design -all
set_host_options -max_cores 16
define_design_lib WORK -path ./work

# Save SVF for Formality
set_svf ../output/Top_multiplier_[clock format [clock seconds] -format "%Y%m%d_%H%M"].svf

# ---------------- Libraries / Search Path (DW enabled) ----------------
set_app_var search_path \
"/home/yuhaoxie/test2/lib \
 /home/yuhaoxie/test2/rtl \
 /NAS/cad/synopsys/syn-S-2021.06-SP2/libraries/syn \
 /NAS/cad/synopsys/syn-S-2021.06-SP2/dw/syn_ver \
 /NAS/cad/synopsys/syn-S-2021.06-SP2/dw \
 /NAS/cad/synopsys/syn-S-2021.06-SP2/minpower"
set_app_var target_library "/home/yuhaoxie/test2/lib/tcbn65lpwc_ccs.db"
set_app_var link_library "* /home/yuhaoxie/test2/lib/tcbn65lpwc_ccs.db /home/yuhaoxie/test2/lib/tpan65lpnv2od3wc.db dw_foundation.sldb"
set_app_var synthetic_library "dw_foundation.sldb"
set_app_var synlib_wait_for_design_license [list "DesignWare-Foundation"]

# NOTE: Removed obsolete variable 'dw_prefer_mc_inside'

# ---------------- Read RTL ----------------
set top_module Top_multiplier
analyze -format sverilog /home/yuhaoxie/test2/rtl/mul88_pe/Top_multiplier.v
analyze -format sverilog /home/yuhaoxie/test2/rtl/mul88_pe/multiplier.v
elaborate $top_module
current_design $top_module
link
uniquify -force

# Basic checks
if {[catch {redirect ../report/report.check_rtl {check_design}} cd_status]} {
  puts "Check Design Error: $cd_status"
  exit 1
} else { puts "Check Design Pass!" }

# ---------------- Pre-compile constraints (Clock/Reset/Units) ----------------
set_units -time ns -capacitance pF

# Clock (external)
remove_driving_cell [get_ports clk]
set_drive 0 [get_ports clk]
create_clock -name clk -period 4 -waveform {0 2} [get_ports clk]
set_ideal_network -no_propagate [get_ports clk]

# Clock uncertainty/latency/transition
set_clock_uncertainty -setup 0.2 [get_clocks clk]
set_clock_uncertainty -hold 0.05 [get_clocks clk]
set_clock_latency -source -min 0.08 [get_clocks clk]
set_clock_latency -source -max 0.4  [get_clocks clk]
set_clock_latency -min 0.08 [get_clocks clk]
set_clock_latency -max 0.4  [get_clocks clk]
set_clock_transition -min 0.04 [get_clocks clk]
set_clock_transition -max 0.08 [get_clocks clk]

# Reset (rst_n active-low)
set_dont_touch_network [get_ports rst_n]
set_false_path -from [get_ports rst_n]
set_ideal_network -no_propagate [get_ports rst_n]
set_drive 0 [get_ports rst_n]

# ---------------- Synthesis options ----------------
set_fix_multiple_port_nets -feedthrough [get_designs *]
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]
set_leakage_optimization  true
set_dynamic_optimization  true
set_max_area 0
set_flatten   false
set_structure true -timing true -boolean false

# Set clock gating style BEFORE compile (library likely lacks ICG cells)
# Use latch-based gating to avoid PWR-191
set_clock_gating_style -sequential_cell latch

# Pre-compile check again
if {[catch {redirect ../report/report.check_beforecompile {check_design}} cd_status2]} {
  puts "Check Design Error before compile: $cd_status2"
  exit 1
} else { puts "Check Design Pass before compile!" }

# ---------------- Compile (DW enabled + capture log) ----------------
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

# ---------------- Conservative pre-CTS IO transitions ----------------
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

# ===================== Power Analysis — Enhanced =====================
# 若设置环境变量 POWER_PROFILE=basic 则回退到 basic；否则执行增强分析
set use_enhanced 1
if {[info exists ::env(POWER_PROFILE)]} {
  if {$::env(POWER_PROFILE) eq "basic"} { set use_enhanced 0 }
}

set ACTIVITY_DIR              ../activity
set SAIF_FILE                "$ACTIVITY_DIR/${top_module}.saif"
set VCD_FILE                 "$ACTIVITY_DIR/${top_module}.vcd"
set TOP_INSTANCE              $top_module

# 缺省选择高努力
set POWER_ANALYSIS_EFFORT     high
# 初始单位按“每周期切换”；若读入 SAIF/VCD 再切换为每秒
set_power_analysis_options -toggle_rate_unit toggles_per_cycle

# 启发式切换（仅在无 SAIF/VCD 时使用）
set DATA_STATIC_PROB          0.5
set DATA_TOGGLE_PER_CYCLE     0.20
set RST_TOGGLE_PER_CYCLE      0.01
set QPIN_TOGGLE_PER_CYCLE     0.10
set OUT_TOGGLE_PER_CYCLE      0.10

proc _file_exists {f} {expr {[string length $f]>0 && [file exists $f]}}

# 统一重置活动信息
reset_switching_activity [current_design]

if {$use_enhanced} {
  if { [_file_exists $SAIF_FILE] || [_file_exists $VCD_FILE] } {
      # 读入外部波形：切换单位设为每秒
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
      # 时钟：1 次/周期
      set clk_ports [get_attribute [get_clocks *] sources]
      if {[sizeof_collection $clk_ports] > 0} {
          set_switching_activity -static_probability 0.5 -toggle_rate 1.0 $clk_ports
      }
      # 复位：很少切换
      if {[sizeof_collection [get_ports rst_n]] > 0} {
          set_switching_activity -static_probability 1.0 -toggle_rate $RST_TOGGLE_PER_CYCLE [get_ports rst_n]
      }
      # 数据输入
      set data_in [remove_from_collection [all_inputs] [list $clk_ports [get_ports rst_n]]]
      if {[sizeof_collection $data_in] > 0} {
          set_switching_activity -static_probability $DATA_STATIC_PROB -toggle_rate $DATA_TOGGLE_PER_CYCLE $data_in
      }
      # 寄存器Q
      set qpins [all_registers -q_pins]
      if {[sizeof_collection $qpins] > 0} {
          set_switching_activity -static_probability 0.5 -toggle_rate $QPIN_TOGGLE_PER_CYCLE $qpins
      }
      # 顶层输出
      if {[sizeof_collection [all_outputs]] > 0} {
          set_switching_activity -static_probability 0.5 -toggle_rate $OUT_TOGGLE_PER_CYCLE [all_outputs]
      }
  }

  # 高努力功耗分析与报告
  redirect -file ../report/${top_module}_${DATE}_power_summary.rpt {
      report_power -hier -analysis_effort $POWER_ANALYSIS_EFFORT -nosplit
  }
  catch { redirect -file ../report/${top_module}_${DATE}_switching_activity_summary.rpt {
      report_switching_activity -hierarchy -summary -nosplit
  }}
} else {
  # BASIC：仅做最基本报告（保持兼容）
  redirect -file ../report/${top_module}_${DATE}_power_summary_basic.rpt {
      report_power -hier -analysis_effort low -nosplit
  }
}
# =================== End of Enhanced Power Analysis ===================

# ---------------- Reports (QoR/Area/Power/CG) ----------------
file mkdir ../report
# 已于上方生成 power_summary，这里保留一份常规合集
redirect -file ../report/${top_module}_${DATE}_report.qor             { report_qor -nosplit }
redirect -file ../report/${top_module}_${DATE}_report.area            { report_area -hierarchy -nosplit }
redirect -file ../report/${top_module}_${DATE}_report.power           { report_power -hierarchy -analysis_effort high -nosplit }
redirect -file ../report/${top_module}_${DATE}_report.clock_gating    { report_clock_gating -structure -verbose -nosplit }

# ---------------- Outputs (Netlist/SDC/SDF/Parasitics) ----------------
change_names -rules sverilog -hierarchy
write      -format verilog -hierarchy -output ../output/${top_module}_${DATE}.v
write_sdc  ../output/${top_module}_${DATE}.sdc
write      -format ddc     -hierarchy -output ../output/${top_module}_${DATE}_compile.ddc
write_sdf  ../output/${top_module}_${DATE}.sdf

# Parasitic (non-signoff)
set _rc_out ../output/${top_module}_${DATE}.rc
if {[catch {write_parasitics -format reduced     -output $_rc_out} wp_err]} {
  puts "WARN: write_parasitics reduced failed: $wp_err"
  if {[catch {write_parasitics -format distributed -output $_rc_out} wp_err2]} {
    puts "ERROR: write_parasitics failed (distributed): $wp_err2"
  } else {
    puts "INFO: Parasitics written in distributed format: $_rc_out"
  }
} else {
  puts "INFO: Parasitics written in reduced format: $_rc_out"
}

# Close SVF
set_svf -off

# Quick summary bundle
redirect -file ../report/${top_module}_${DATE}_area_recovery.log {
  report_qor -nosplit
  report_area -hierarchy -nosplit
  report_power -hierarchy -analysis_effort high -nosplit
}

puts "DONE. Netlist/SDC/SDF/RC and reports are under ../output and ../report."
