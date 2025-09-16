#!/usr/bin/env tclsh
#==============================================================================
# 0. 文件句柄与路径
#==============================================================================
set outputfile "./work/script.tcl"
set fileToWrite [open $outputfile a]
puts $fileToWrite "\n#============================================================================#"
puts $fileToWrite "# Synthesize #"
puts $fileToWrite "#============================================================================#"

# ----------------------------------
# 在生成的脚本里放入通用工具过程：
#   cmd_exists: 判断命令是否存在
#   if_cmd: 仅当命令存在时执行，避免在 DC 中产生 CMD-005 噪声
# ----------------------------------
puts $fileToWrite {
# ---- Utility procs (keep logs clean in different Synopsys tools) ----
proc cmd_exists {name} { expr {[llength [info commands $name]] > 0} }
proc if_cmd {name args} {
  if {[cmd_exists $name]} { uplevel 1 [list $name] $args }
}
}

# Prevent assignment statements in the Verilog netlist.
puts $fileToWrite {set_fix_multiple_port_nets -feedthrough [get_designs *]}
puts $fileToWrite {set_fix_multiple_port_nets -all -buffer_constants [get_designs *]}

# Power optimization settings
puts $fileToWrite {set_leakage_optimization true}
puts $fileToWrite {set_dynamic_optimization true}

# Area constraint (0 means optimize for timing)
puts $fileToWrite {set_max_area 0}
# NOTE: 'set_max_area_percentage' 在 DC 不支持，已删掉以保持日志整洁

# Structuring and mapping effort
puts $fileToWrite {set_structure true -timing true -boolean false}
# Set clock gating style BEFORE compile (library may not have ICG cells)
puts $fileToWrite {set_clock_gating_style -sequential_cell latch}

# Final check before compiling
puts $fileToWrite {
if {[catch {redirect ../report/report.check_beforecompile {check_design}} cd_status]} {
  puts "Check Design Error before compile: $cd_status"
  exit
} else {
  puts "Check Design Pass before compile!"
}
}

puts $fileToWrite {set top_module [get_object_name [current_design]]}

# --- Section 3: Compile ---
puts $fileToWrite "\n# --------------- Compile (DW enabled + capture log) ---------------"
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
  redirect -file ../log/${top_module}_${DATE}_compile_ultra.log {
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
puts $fileToWrite "\n# -------- Conservative pre-CTS IO transitions --------"
puts $fileToWrite {
# Apply input transition only to non-ideal inputs (exclude clk/rst_n)
set nonideal_inputs [remove_from_collection [all_inputs] [list [get_ports clk] [get_ports rst_n]]]
if {[sizeof_collection $nonideal_inputs] > 0} {
  set_input_transition 0.5 $nonideal_inputs
}
}

puts $fileToWrite {
# ===================== Power Analysis (Clean) =====================
# 策略：优先用 SAIF/VCD；否则用向量无关“max”上限，适合 pre-CTS 功耗预算
set ACTIVITY_DIR ../activity
set SAIF_FILE "$ACTIVITY_DIR/${top_module}.saif"
set VCD_FILE  "$ACTIVITY_DIR/${top_module}.vcd"
set TOP_INSTANCE $top_module

# ------ ① 先拿时钟端口，供后面复用 ------
set clk_ports [get_ports -filter "direction==in" [get_attribute [get_clocks *] sources]]

# 优先读 SAIF；没有就试 VCD→SAIF；都没有就向量无关
if {[file exists $SAIF_FILE]} {
  if_cmd read_saif -input $SAIF_FILE -instance $TOP_INSTANCE -verbose
} elseif {[file exists $VCD_FILE]} {
  set _tmp ../report/_vcd2saif.saif
  if {![catch {sh vcd2saif -input $VCD_FILE -output $_tmp -instance $TOP_INSTANCE}]} {
    if_cmd read_saif -input $_tmp -instance $TOP_INSTANCE -verbose
    catch {file delete $_tmp}
  } else {
    puts "WARN: vcd2saif failed; fall back to vectorless heuristics"
  }
} else {
  puts "INFO: No SAIF/VCD found — using vectorless MAX-toggling for pre-CTS budget"
  
  # 时钟：理想网络，每周期必翻 → toggle rate = 1.0
  if {[sizeof_collection $clk_ports] > 0} {
    set_switching_activity -static_probability 0.5 -toggle_rate 1.0 $clk_ports
  }
  
  # 复位：几乎不动 → 0.01
  if {[sizeof_collection [get_ports rst_n]] > 0} {
    set_switching_activity -static_probability 1.0 -toggle_rate 0.01 [get_ports rst_n]
  }
  
  # 数据输入：满载猝发上限 0.30
  set data_in [remove_from_collection [all_inputs] [list $clk_ports [get_ports rst_n]]]
  if {[sizeof_collection $data_in] > 0} {
    set_switching_activity -static_probability 0.5 -toggle_rate 0.30 $data_in
    # ← 修改：pre-CTS 用 max 值，每 3~4 周期翻一次
  }
  
  # 寄存器 Q：pipeline 满载几乎全翻 → 0.80
  set qpins [get_pins -of_objects [all_registers]]
  if {[sizeof_collection $qpins] > 0} {
    set_switching_activity -static_probability 0.5 -toggle_rate 0.80 $qpins
    # ← 修改：max 上限，保守估峰值电流
  }
  
  # 顶层输出：下游每周期采 → 0.40
  if {[sizeof_collection [all_outputs]] > 0} {
    set_switching_activity -static_probability 0.5 -toggle_rate 0.40 [all_outputs]
    # ← 修改：max 上限
  }
}
}

puts $fileToWrite "\n# =================== End of Power Analysis ==================="


flush $fileToWrite
close $fileToWrite
puts "Conservative Pre-CTS script generated (no file output section)."
