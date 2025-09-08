#!/usr/bin/env tclsh

#==============================================================================
set outputfile     "./work/script.tcl"
file mkdir ./work
file mkdir ./report
set fileToWrite    [open $outputfile w]   ;# 一次性新建，不再追加


puts $fileToWrite "\n#============================================================================#"
puts $fileToWrite "#                                Synthesize                                   #"
puts $fileToWrite "#============================================================================#"

puts $fileToWrite {# Prevent assignment statements in the Verilog netlist.}
puts $fileToWrite {set_fix_multiple_port_nets -feedthrough}
puts $fileToWrite {set_fix_multiple_port_nets -all -buffer_constants}

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
if [catch {redirect ./report/report.check_beforecompile {check_design}} cd_status] {
    puts "Check Design Error before compile: $cd_status"
    exit
} else {
    puts "Check Design Pass before compile!"
}
}

puts $fileToWrite "\n#********************Compile*******************}"
puts $fileToWrite {compile_ultra -no_autoungroup -no_seq_output_inversion -no_boundary_optimization -gate_clock}

##############################################################################
# 2. 保守约束（Pre-CTS 偏大功耗）
##############################################################################
puts $fileToWrite "\n# ---------- Conservative constraints for Pre-CTS power ----------"

# 2.1 输入过渡
puts $fileToWrite "set_input_transition 0.5 \\[all_inputs\\]"

# 2.2 时钟门控风格
puts $fileToWrite "set_clock_gating_style -positive_edge_logic integrated"

# 2.3 频率加压 15 %
puts $fileToWrite {
if {![info exists CLOCK_PERIOD]} {set CLOCK_PERIOD 10.0}
create_clock -period [expr ${CLOCK_PERIOD} * 0.85] [get_ports [lindex [get_clocks *] 0]]
}

##############################################################################
# 3. 功耗分析 —— 双重策略（外部波形 / 向量无关）
##############################################################################
puts $fileToWrite "\n#==================== Post-compile Power Strategy ===================="

# 3.1 用户可见变量（robust 目录 & 文件检查）
puts $fileToWrite {
set ACTIVITY_DIR   ./activity                 ;# 与 work/ 同级
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

# 3.2 工具函数
puts $fileToWrite {
proc _file_exists {f} {expr {[string length $f]>0 && [file exists $f]}}

remove_switching_activity [current_design]
}

# 3.3 分支：外部波形 or 向量无关
puts $fileToWrite {
if {[_file_exists $SAIF_FILE] || [_file_exists $VCD_FILE]} {
    # ---------- 外部波形模式 ----------
    set_power_analysis_mode -toggle_rate_unit toggles_per_second
    if {[_file_exists $SAIF_FILE]} {
        read_saif -input $SAIF_FILE -instance $TOP_INSTANCE -verbose
    } else {
        set _tmp ./report/_vcd2saif.saif
        if {![catch {sh vcd2saif -input $VCD_FILE -output $_tmp -instance $TOP_INSTANCE}]} {
            read_saif -input $_tmp -instance $TOP_INSTANCE -verbose
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

    # 其余输入
    set_switching_activity -static_probability 0.5 -toggle_rate 1.0 [all_inputs]

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
# 5. 收尾
##############################################################################
close $fileToWrite
puts "Generated conservative Pre-CTS script: $outputfile"
puts "Run:  dc_shell -f $outputfile | tee ./report/script.log"