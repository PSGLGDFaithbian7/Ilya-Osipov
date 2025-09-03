#!/usr/bin/env tclsh

## choose script to write
set outputfile "./work/script.tcl"

# 确保输出目录存在
file mkdir [file dirname $outputfile]
file mkdir "./results"


set fileToWrite [open $outputfile a]

# find Top_Module
if {![file exists ./setup/library.lst]} {
    error "缺少 ./setup/library.lst 文件，无法解析 TopModule。"
}
set fh_lib [open ./setup/library.lst r]
set top_module ""
while {[gets $fh_lib line] >= 0} {
    set line [string trim [lindex [split $line "#"] 0]]
    if {$line eq ""} { continue }

    if {[regexp -nocase {^TopModule:\s*(\S+)$} $line -> tm]} {
        set top_module $tm
        continue
    }
}
close $fh_lib

if {$top_module eq ""} {
    error "在 ./setup/library.lst 中未找到 TopModule (应为：'TopModule: <name>')"
}

# ====================== 开始写入目标脚本内容 ======================

puts $fileToWrite {#============================================================================#}
puts $fileToWrite {#                                Synthesize                                   #}
puts $fileToWrite {#============================================================================#}

puts $fileToWrite {# Prevent assignment statements in the Verilog netlist.}
puts $fileToWrite {set_fix_multiple_port_nets -feedthrough}
puts $fileToWrite {set_fix_multiple_port_nets -all -buffer_constants}

puts $fileToWrite {# Optimize leakage power}
puts $fileToWrite {set_leakage_optimization true}
puts $fileToWrite {# Optimize dynamic power}
puts $fileToWrite {set_dynamic_optimization true}

# 使用 top_module 作为当前设计
puts $fileToWrite "current_design [list $top_module]"

puts $fileToWrite {# Enables the Synopsys Module Compiler to generate arithmetic DesignWare parts.}
puts $fileToWrite {set_app_var dw_prefer_mc_inside true}
puts $fileToWrite {# Area constraint (0 means no explicit limit; let tool optimize)}
puts $fileToWrite {set_max_area 0}

puts $fileToWrite {#************************** opt for timing ************************************}
puts $fileToWrite {# Logic flatten preference}
puts $fileToWrite {set_flatten false}
puts $fileToWrite {set_structure true -timing true -boolean false}
puts $fileToWrite {#****************************************************************************}

puts $fileToWrite {# Let Design Compiler set priority to formal verification instead of optimization}
puts $fileToWrite {# set_app_var simplified_verification_mode true}

puts $fileToWrite {set_app_var compile_ultra_ungroup_dw false}

puts $fileToWrite {# remove_unconnected_ports [find -hierarchy cell "*"]}
puts $fileToWrite {# remove_unconnected_ports -blast_buses [find -hierarchy cell "*"]}

puts $fileToWrite {
# 将 check_design 的输出重定向到报告文件，同时获取返回码
set cd_status [redirect ./report/report.check_beforecompile {check_design}]

if {$cd_status != 0} {
    puts "Check Design Error!"
    exit
} else {
    puts "Check Design Pass!"
}
}

puts $fileToWrite {# insert_clock_gating clockgating}
puts $fileToWrite {# set_clock_gating_style -minimum_bitwidth 4 -sequential_cell latch -positive_edge_logic integrated -max_fanout 12}

puts $fileToWrite {#********************Compile*******************}
puts $fileToWrite {compile_ultra -no_autoungroup -no_seq_output_inversion -no_boundary_optimization}

close $fileToWrite
