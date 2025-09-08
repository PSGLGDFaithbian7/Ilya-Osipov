#!/usr/bin/env tclsh
#==============================================================================
# 0. 文件句柄（保持你原样）
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

puts $fileToWrite "\n# DesignWare settings"
puts $fileToWrite {set_app_var dw_prefer_mc_inside true}

puts $fileToWrite "\n# Area constraint (0 means optimize for timing)"
puts $fileToWrite {set_max_area 0}

puts $fileToWrite "\n# Structuring and mapping effort"
puts $fileToWrite {set_flatten false}
puts $fileToWrite {set_structure true -timing true -boolean false}

puts $fileToWrite {
# Final check before compiling
if [catch {redirect ../report/report.check_beforecompile {check_design}} cd_status] {
    puts "Check Design Error before compile: $cd_status"
    exit
} else {
    puts "Check Design Pass before compile!"
}
}

puts $fileToWrite "\n#********************Compile*******************}"
puts $fileToWrite {compile_ultra -no_autoungroup -no_seq_output_inversion -no_boundary_optimization -gate_clock}

# 添加编译后检查（保持你原样）
puts $fileToWrite {
if {[get_attribute [current_design] has_errors]} {
    puts "Compile failed! See report for details."
    exit
}
}

##############################################################################
# 2. 保守约束（保持你原样）
##############################################################################
puts $fileToWrite "\n# ---------- Conservative constraints for Pre-CTS power ----------"

# 2.1 输入过渡（保持）
puts $fileToWrite "set_input_transition 0.5 \\[all_inputs\\]"

# 2.2 时钟门控风格（保持）
puts $fileToWrite "set_clock_gating_style -positive_edge_logic integrated"

# 2.3 频率加压（保持）
puts $fileToWrite {
if {![info exists CLOCK_PERIOD]} {set CLOCK_PERIOD 10.0}
set clks [get_clocks *]
if {[sizeof_collection $clks] == 0} {
    puts "No clocks found! Cannot apply frequency scaling."
    exit
}
create_clock -period [expr ${CLOCK_PERIOD} * 0.85] [get_ports [lindex $clks 0]]
}

##############################################################################
# 3. 功耗分析 —— 双重策略（保持你原样）
##############################################################################
puts $fileToWrite "\n#==================== Post-compile Power Strategy ===================="

# 3.1 用户可见变量（保持）
puts $fileToWrite {
set ACTIVITY_DIR   ../activity
set SAIF_FILE      "$ACTIVITY_DIR/${top_module}.saif"
set VCD_FILE       "$ACTIVITY_DIR/${top_module}.vcd"
set TOP_INSTANCE   $top_module

# 健壮性检查
if {![file exists $ACTIVITY_DIR]} {
    puts "WARNING: Directory $ACTIVITY_DIR not found — switch to conservative vectorless estimation"
    set SAIF_FILE ""; set VCD_FILE ""
} else {
    if {![file exists $SAIF_FILE] && ![file exists $VCD_FILE]} {
        puts "WARNING: Neither $SAIF_FILE nor $VCD_FILE found — switch to conservative vectorless estimation"
        set SAIF_FILE ""; set VCD_FILE ""
    }
}
}

# 3.2 工具函数（保持）
puts $fileToWrite {
proc _file_exists {f} {expr {[string length $f]>0 && [file exists $f]}}
remove_switching_activity [current_design]
}

# 3.3 分支：外部波形 or 向量无关（保持你原样）
puts $fileToWrite {
if {[_file_exists $SAIF_FILE] || [_file_exists $VCD_FILE]} {
    # ---------- 外部波形模式 ----------
    set_power_analysis_mode -toggle_rate_unit toggles_per_second
    if {[_file_exists $SAIF_FILE]} {
        read_saif -input $SAIF_FILE -instance $TOP_INSTANCE -verbose
    } else {
        set _tmp ../report/_vcd2saif.saif
        if {![catch {sh vcd2saif -input $VCD_FILE -output $_tmp -instance $TOP_INSTANCE}]} {
            read_saif -input $_tmp -instance $TOP_INSTANCE -verbose
            file delete $_tmp
        } else {
            puts "WARN: vcd2saif failed; fall back to vectorless"
        }
    }
} else {
    # ---------- 向量无关保守模式 ----------
    set_power_analysis_mode -toggle_rate_unit toggles_per_cycle

    # 时钟
    set clk_ports [get_attribute [get_clocks *] sources]
    if {[sizeof_collection $clk_ports] > 0} {
        set_switching_activity -static_probability 0.5 -toggle_rate 1.0 $clk_ports
    }

    # 复位
    if {[sizeof_collection [get_ports rst_n]] > 0} {
        set_switching_activity -static_probability 1.0 -toggle_rate 0.01 [get_ports rst_n]
    }

    # 其余输入（移除时钟和复位）
    set data_inputs [remove_from_collection [all_inputs] [list $clk_ports [get_ports rst_n]]]
    if {[sizeof_collection $data_inputs] > 0} {
        set_switching_activity -static_probability 0.5 -toggle_rate 1.0 $data_inputs
    }

    # 输出 & 内部节点
    set_switching_activity -static_probability 0.5 -toggle_rate 1.0 [all_outputs]
    set_switching_activity -static_probability 0.5 -toggle_rate 1.0 [all_registers -q_pins]
    set comb_out [remove_from_collection [get_pins -hier -filter direction==out] [all_registers -q_pins]]
    if {[sizeof_collection $comb_out] > 0} {
        set_switching_activity -static_probability 0.5 -toggle_rate 0.8 $comb_out
    }
}
}

##############################################################################
# 4. 保守加码（两项，零出错）
##############################################################################
puts $fileToWrite "\n# ---------- Extra conservative boost ----------"

# ① 输入过渡再放大 → 内部短路功耗↑
puts $fileToWrite "set_input_transition 1.0 \\[all_inputs\\]   ;# 比 0.5 更保守"

# ② 所有组合输出节点也拉到 1.0 toggle/cycle，彻底堵死“零翻转”低估
puts $fileToWrite {
set combNode [remove_from_collection [get_pins -hier -filter direction==out] [all_registers -q_pins]]
if {[sizeof_collection $combNode] > 0} {
    set_switching_activity -static_probability 0.5 -toggle_rate 1.0 $combNode
}
}

##############################################################################
# 5. 报告生成（保持你原样）
##############################################################################
puts $fileToWrite "set DATE \[clock format \[clock seconds\] -format \"%Y%m%d_%H%M%S\"\]"
puts $fileToWrite "redirect -file ../report/${top_module}_\${DATE}_report.qor            {report_qor -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_\${DATE}_report.area          {report_area -hierarchy -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_\${DATE}_report.power         {report_power -hierarchy -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_\${DATE}_report.clock_gating  {report_clock_gating -structure -verbose -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_\${DATE}_report.activity_unannotated.rpt {report_switching_activity -unannotated -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_\${DATE}_report.activity_summary.rpt   {report_switching_activity -hierarchy -summary -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_\${DATE}_report.power_detail.rpt       {report_power -analysis_effort high -hierarchy}"

# ------------------------------------------------------------------------------
# 6. 收尾（保持你原样）
# ------------------------------------------------------------------------------
flush $fileToWrite
close $fileToWrite
puts "Generated conservative Pre-CTS script: [file normalize $outputfile]"
puts "Run:  dc_shell -f $outputfile | tee ../report/script.log"
