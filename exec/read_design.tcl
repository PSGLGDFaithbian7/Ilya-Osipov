#!/usr/bin/env tclsh
# =============================================================================
# read_design.tcl  (DC-friendly)
# - 解析 ./setup/library.lst 和 ./setup/rtl_design.lst
# - 生成 work/script.tcl，包含正确的Design Compiler命令
#   * 包含目录通过：analyze -vcs "+incdir+dir1 +incdir+dir2 ..."
#   * 宏定义通过：analyze -define {NAME NAME2=VAL ...}
# - 将.sv/.v视为SystemVerilog，跳过.svh，支持.vhdl
# =============================================================================

# ----------- 完整性检查 -----------
if {![file exists ./work]}  { file mkdir ./work }
if {![file exists ./setup]} { error "缺少 ./setup 目录" }
if {![file exists ./setup/rtl_design.lst]} { error "缺少 ./setup/rtl_design.lst" }
if {![file exists ./setup/library.lst]}    { error "缺少 ./setup/library.lst" }

set DATE [clock format [clock seconds] -format "%Y%m%d_%H%M"]
set out_script ./work/script.tcl
set fh_out [open $out_script w]

# ----------- 解析 library.lst -----------
set fh_lib [open ./setup/library.lst r]
set incdirs {}
set defines {}
set top_module ""

while {[gets $fh_lib line] >= 0} {
    set line [string trim [lindex [split $line "#"] 0]]
    if {$line eq ""} { continue }

    # TopModule: NAME
    if {[regexp -nocase {^TopModule:\s*(\S+)$} $line -> tm]} {
        set top_module $tm
        continue
    }
    # Incdir: /path
    if {[regexp -nocase {^Incdir:\s*(\S.*)$} $line -> idir]} {
        lappend incdirs [string trim $idir]
        continue
    }
    # +incdir+/path
    if {[regexp {^\+incdir\+(.+)$} $line -> idir2]} {
        lappend incdirs [string trim $idir2]
        continue
    }
    # Define: NAME 或 NAME=VAL
    if {[regexp -nocase {^Define:\s*([A-Za-z_]\w*)(?:=(\S+))?} $line -> dname dval]} {
        if {$dval ne ""} { lappend defines "${dname}=$dval" } else { lappend defines $dname }
        continue
    }
    # -DNAME 或 -DNAME=VAL
    if {[regexp {^-D([A-Za-z_]\w*)(?:=(\S+))?} $line -> dname2 dval2]} {
        if {$dval2 ne ""} { lappend defines "${dname2}=$dval2" } else { lappend defines $dname2 }
        continue
    }
}
close $fh_lib

if {$top_module eq ""} {
    error "在 ./setup/library.lst 中未找到 TopModule (应为：'TopModule: <name>')"
}

# 构建 analyze 选项：
#   -vcs "+incdir+dir1 +incdir+dir2 ..."  (DC支持 -vcs 传递VCS风格的选项)
#   -define {MACRO MACRO=VAL ...}         (DC原生选项)
set inc_arg_vcs ""
if {[llength $incdirs] > 0} {
    set inc_tokens {}
    foreach d $incdirs { lappend inc_tokens "+incdir+$d" }
    # 用引号包裹，确保DC将所有标记视为单个参数传递给 -vcs
    set inc_arg_vcs "-vcs \"[join $inc_tokens { }]\""
}
set def_arg ""
if {[llength $defines] > 0} {
    set def_arg "-define [list {*}$defines]"
}

# ----------- 生成头部 & WORK 库 -----------
puts $fh_out "######### Read Design (for dc_shell -t) ###########"
puts $fh_out "define_design_lib WORK -path ./work"
puts $fh_out ""

# ----------- 解析 rtl_design.lst 并生成 analyze 命令 -----------
set fh_rtl [open ./setup/rtl_design.lst r]
while {[gets $fh_rtl line] >= 0} {
    set line [string trim [lindex [split $line "#"] 0]]
    if {$line eq ""} { continue }

    set filepath $line

    # 跳过头文件
    if {[regexp -nocase {\.svh$} $filepath]} {
        continue
    }
    # SystemVerilog (.sv 和 .v)
    if {[regexp -nocase {\.sv$} $filepath] || [regexp -nocase {\.v$} $filepath]} {
        puts $fh_out "analyze -format sverilog $inc_arg_vcs $def_arg [list $filepath]"
        continue
    }
    # VHDL
    if {[regexp -nocase {\.vhdl$} $filepath]} {
        puts $fh_out "analyze -format VHDL [list $filepath]"
        continue
    }

    puts $fh_out "# WARN: 无法识别的文件扩展名，已跳过: $filepath"
}
close $fh_rtl

# ----------- elaborate / link / uniquify / check / write -----------
puts $fh_out ""
puts $fh_out "elaborate [list $top_module]"
puts $fh_out "current_design [list $top_module]"
puts $fh_out "link"
puts $fh_out "uniquify -force"

puts $fh_out {

set cd_status [redirect ./report/report.check_rtl {check_design}]
if {$cd_status != 0} {
    puts "Check Design Error!"
    exit
} else {
    puts "Check Design Pass!"
}
}


puts $fh_out "# ----------- Use for MultiVoltage Design -----------"
puts $fh_out "# set auto_insert_level_shifters_on_clocks all"
puts $fh_out "# set auto_insert_level_shifters_on_nets all"
puts $fh_out "#--------area power suggest dont---------"
puts $fh_out "# set_dont_use [get_lib_cells */LAP2UM]"


# 将DDC写入 ../output/<top>_<DATE>_link.ddc
set outdir [file join ".." "output"]
if {![file exists $outdir]} { file mkdir $outdir }
set output_file [file join $outdir "${top_module}_${DATE}_link.ddc"]
puts $fh_out "write_file -format ddc -hierarchy -output [list $output_file]"
close $fh_out

# 从tclsh运行时提示
if {[info exists argv0] && $argv0 ne ""} {
    puts "已生成 $out_script"
    puts "TopModule: $top_module"
    if {[llength $incdirs]} { puts "包含目录: $incdirs" }
    if {[llength $defines]} { puts "宏定义:     $defines" }
}