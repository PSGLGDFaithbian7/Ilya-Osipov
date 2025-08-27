#!/usr/bin/env tclsh

# 错误退出函数
proc errorExit {message} {
    puts stderr "错误: $message"
    exit 1
}

# 检查目录
foreach dir {work setup} {
    if {![file exists ./$dir]} {
        if {$dir eq "work"} {
            if {[catch {file mkdir ./$dir} err]} {
                errorExit "无法创建 ./$dir 目录: $err"
            }
        } else {
            errorExit "缺少 ./$dir 目录"
        }
    }
}

# 检查文件
set required_files {setup/clk.lst}
foreach file $required_files {
    if {![file exists ./$file]} {
        errorExit "缺少 ./$file 文件"
    }
}

# 获取时间戳
if {[catch {set DATE [exec date "+%Y%m%d_%H%M"]} err]} {
    set DATE [clock format [clock seconds] -format "%Y%m%d_%H%M"]
}

# 打开文件
if {[catch {
    set fileToWrite [open ./work/script.tcl a]
    set fileToRead [open ./setup/clk.lst r]
} err]} {
    errorExit "无法打开文件: $err"
}

# 初始化列表
set ClockPort_List {}
set ClockName_List {}

# 读取 clk.lst 文件
while {[gets $fileToRead line] >= 0} {
    set line [string trim $line]
    if {[string match "#*" $line] || $line eq ""} continue

    set items [split $line "|"]
    set clean_items {}
    foreach item $items {
        set item [string trim $item]
        if {[regexp {^[^:]+:\s*(.*)$} $item -> value]} {
            lappend clean_items [string trim $value]
        } else {
            lappend clean_items $item
        }
    }

    lassign $clean_items ClockName Period Rise Fall ClockPort

    # 检查数值有效性
    if {![string is double -strict $Period] || $Period <= 0} {
        errorExit "无效的 Period 值: '$Period' 在 clk.lst 中，行: $line"
    }
    if {![string is double -strict $Rise]} {
        errorExit "无效的 Rise 值: '$Rise' 在 clk.lst 中，行: $line"
    }
    if {![string is double -strict $Fall]} {
        errorExit "无效的 Fall 值: '$Fall' 在 clk.lst 中，行: $line"
    }

    # 计算参数
    set CLK_SKEW            [expr {$Period * 0.05}]
    set CLK_SOURCE_LATENCY  [expr {$Period * 0.1}]
    set CLK_NETWORK_LATENCY [expr {$Period * 0.1}]
    set CLK_TRAN            [expr {$Period * 0.01}]
    set INPUT_DELAY_MAX     [expr {$Period * 0.4}]
    set INPUT_DELAY_MIN     0
    set OUTPUT_DELAY_MAX    [expr {$Period * 0.4}]
    set OUTPUT_DELAY_MIN    0

    # 输出 DC 命令
    if {[string first "/" $ClockPort] >= 0} {
        puts $fileToWrite "######## Inside CLOCK ########"
        puts $fileToWrite "create_clock -name $ClockName \[get_pins -hierarchical $ClockPort\] -period $Period -waveform \[list $Rise $Fall\]"
        puts $fileToWrite "set_dont_touch_network \[get_pins -hierarchical $ClockPort\]"
        puts $fileToWrite "set_ideal_network -no_propagate \[get_pins -hierarchical $ClockPort\]"
    } else {
        puts $fileToWrite "######## Outside CLOCK ########"
        puts $fileToWrite "remove_driving_cell \[get_ports $ClockPort\]"
        puts $fileToWrite "set_drive 0 \[get_ports $ClockPort\]"
        puts $fileToWrite "create_clock -name $ClockName \[get_ports $ClockPort\] -period $Period -waveform \[list $Rise $Fall\]"
        puts $fileToWrite "set_dont_touch_network \[get_ports $ClockPort\]"
        puts $fileToWrite "set_ideal_network -no_propagate \[get_ports $ClockPort\]"
        lappend ClockPort_List $ClockPort
    }

    puts $fileToWrite "######## SKEW & LATENCY ########"
    puts $fileToWrite "set_clock_uncertainty $CLK_SKEW \[get_clocks $ClockName\]"
    puts $fileToWrite "set_clock_latency -source -max $CLK_SOURCE_LATENCY \[get_clocks $ClockName\]"
    puts $fileToWrite "set_clock_latency -max $CLK_NETWORK_LATENCY \[get_clocks $ClockName\]"
    puts $fileToWrite "set_clock_transition -max $CLK_TRAN \[get_clocks $ClockName\]"

    lappend ClockName_List $ClockName
    puts $fileToWrite ""
}

# 输出时钟列表信息
puts "\nINFO : CKNAME_list : $ClockName_List"
puts "INFO : CKPORT_list : $ClockPort_List\n"

# 多时钟 false path 设置
if {[llength $ClockName_List] > 1} {
    puts $fileToWrite "######## FALSE_PATH ########"
    for {set i 0} {$i < [llength $ClockName_List]} {incr i} {
        for {set j [expr {$i + 1}]} {$j < [llength $ClockName_List]} {incr j} {
            set from_clk [lindex $ClockName_List $i]
            set to_clk [lindex $ClockName_List $j]
            puts $fileToWrite "set_false_path -from \[get_clocks $from_clk\] -to \[get_clocks $to_clk\]"
            puts $fileToWrite "set_false_path -from \[get_clocks $to_clk\] -to \[get_clocks $from_clk\]"
        }
    }
}

# 关闭文件
catch {close $fileToRead}
catch {close $fileToWrite}
