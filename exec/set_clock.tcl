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

# Clock uncertainty factors (relative to Period)
set UNC_SETUP_FACTOR        0.05    ;# 5% of period for setup uncertainty
set UNC_HOLD_FACTOR         0.0125  ;# 1.25% of period for hold uncertainty (smaller than setup)

# Clock latency factors (relative to Period)
# Source latency: from external board/PLL to design ref point
set SRC_LAT_MAX_FACTOR      0.10
set SRC_LAT_MIN_FACTOR      0.02
# Network latency: inside design (pre-CTS target tree)
set NET_LAT_MAX_FACTOR      0.10
set NET_LAT_MIN_FACTOR      0.02

# Clock transition factors (relative to Period) — pre-CTS assumed quality
set TRAN_MAX_FACTOR         0.02    ;# e.g., 2% of period
set TRAN_MIN_FACTOR         0.01

# IO delay factors (placeholder; replace with real interface budgets later)
set INPUT_DELAY_MAX_FACTOR  0.40
set INPUT_DELAY_MIN_FACTOR  0.00
set OUTPUT_DELAY_MAX_FACTOR 0.40
set OUTPUT_DELAY_MIN_FACTOR 0.00

# Behavior switches
set PRE_CTS                 1       ;# this snippet is for pre-CTS
set LOCK_CLOCK_NET          0       ;# 1 to set_dont_touch_network on clock net; 0 to avoid over-constraining

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

    # 至少需要 ClockName, Period, ClockPort
    if {[llength $clean_items] < 3} {
        errorExit "clk.lst 行缺少必要字段: $line (至少需要 ClockName, Period, ClockPort)"
    }

    lassign $clean_items ClockName Period Rise Fall ClockPort

    # 默认 Rise 和 Fall 如果未提供或无效
    if {![string is double -strict $Rise]} {
        set Rise 0.0
    }
    if {![string is double -strict $Fall]} {
        set Fall [expr {$Period / 2.0}]
    }

    # 检查必填数值有效性
    if {![string is double -strict $Period] || $Period <= 0} {
        errorExit "无效的 Period 值: '$Period' 在 clk.lst 中，行: $line"
    }
    if {$ClockName eq "" || $ClockPort eq ""} {
        errorExit "ClockName 或 ClockPort 为空 在 clk.lst 中，行: $line"
    }

    # --------------------------
    # Derived values (from Period)
    # --------------------------
    set CLK_UNC_SETUP        [expr {$Period * $UNC_SETUP_FACTOR}]
    set CLK_UNC_HOLD         [expr {$Period * $UNC_HOLD_FACTOR}]
    set CLK_SRC_LAT_MAX      [expr {$Period * $SRC_LAT_MAX_FACTOR}]
    set CLK_SRC_LAT_MIN      [expr {$Period * $SRC_LAT_MIN_FACTOR}]
    set CLK_NET_LAT_MAX      [expr {$Period * $NET_LAT_MAX_FACTOR}]
    set CLK_NET_LAT_MIN      [expr {$Period * $NET_LAT_MIN_FACTOR}]
    set CLK_TRAN_MAX         [expr {$Period * $TRAN_MAX_FACTOR}]
    set CLK_TRAN_MIN         [expr {$Period * $TRAN_MIN_FACTOR}]
    set INPUT_DELAY_MAX      [expr {$Period * $INPUT_DELAY_MAX_FACTOR}]
    set INPUT_DELAY_MIN      [expr {$Period * $INPUT_DELAY_MIN_FACTOR}]
    set OUTPUT_DELAY_MAX     [expr {$Period * $OUTPUT_DELAY_MAX_FACTOR}]
    set OUTPUT_DELAY_MIN     [expr {$Period * $OUTPUT_DELAY_MIN_FACTOR}]

    # --------------------------
    # Clock creation (port vs hierarchical pin)
    # --------------------------
    if {[string first "/" $ClockPort] >= 0} {
        puts $fileToWrite "######## Inside CLOCK (hierarchical pin) ########"
        puts $fileToWrite "create_clock -name $ClockName -period $Period -waveform \[list $Rise $Fall\] \[get_pins -hierarchical $ClockPort\]"
        if {$LOCK_CLOCK_NET} {
            puts $fileToWrite "set_dont_touch_network \[get_pins -hierarchical $ClockPort\]"
        }
        if {$PRE_CTS} {
            puts $fileToWrite "set_ideal_network -no_propagate \[get_pins -hierarchical $ClockPort\]"
        }
    } else {
        puts $fileToWrite "######## Outside CLOCK (top port) ########"
        # For top-level clock port, remove default driver and set ideal drive to avoid external driver side-effects
        puts $fileToWrite "remove_driving_cell \[get_ports $ClockPort\]"
        puts $fileToWrite "set_drive 0 \[get_ports $ClockPort\]"
        puts $fileToWrite "create_clock -name $ClockName -period $Period -waveform \[list $Rise $Fall\] \[get_ports $ClockPort\]"
        if {$LOCK_CLOCK_NET} {
            puts $fileToWrite "set_dont_touch_network \[get_ports $ClockPort\]"
        }
        if {$PRE_CTS} {
            puts $fileToWrite "set_ideal_network -no_propagate \[get_ports $ClockPort\]"
        }
        lappend ClockPort_List $ClockPort
    }

    # --------------------------
    # Uncertainty, Latencies, Transition
    # --------------------------
    puts $fileToWrite "######## Uncertainty (split setup/hold) ########"
    puts $fileToWrite "set_clock_uncertainty -setup $CLK_UNC_SETUP \[get_clocks $ClockName\]"
    puts $fileToWrite "set_clock_uncertainty -hold  $CLK_UNC_HOLD  \[get_clocks $ClockName\]"

    puts $fileToWrite "######## Source & Network Latency (min/max) ########"
    puts $fileToWrite "set_clock_latency -source -min $CLK_SRC_LAT_MIN \[get_clocks $ClockName\]"
    puts $fileToWrite "set_clock_latency -source -max $CLK_SRC_LAT_MAX \[get_clocks $ClockName\]"
    puts $fileToWrite "set_clock_latency -min $CLK_NET_LAT_MIN \[get_clocks $ClockName\]"
    puts $fileToWrite "set_clock_latency -max $CLK_NET_LAT_MAX \[get_clocks $ClockName\]"

    puts $fileToWrite "######## Clock Transition (min/max) ########"
    puts $fileToWrite "set_clock_transition -min $CLK_TRAN_MIN \[get_clocks $ClockName\]"
    puts $fileToWrite "set_clock_transition -max $CLK_TRAN_MAX \[get_clocks $ClockName\]"
    # --------------------------
    # IO timing placeholders (commented; fill your port lists when available)
    # --------------------------
    puts $fileToWrite "######## IO Timing Examples (fill real ports & uncomment) ########"
    puts $fileToWrite "# set_input_delay  -max $INPUT_DELAY_MAX -min $INPUT_DELAY_MIN  -clock \[get_clocks $ClockName\] \[get_ports {<in_ports_here>} \]"
    puts $fileToWrite "# set_output_delay -max $OUTPUT_DELAY_MAX -min $OUTPUT_DELAY_MIN -clock \[get_clocks $ClockName\] \[get_ports {<out_ports_here>} \]"

    # Bookkeeping
    lappend ClockName_List $ClockName
    puts $fileToWrite ""
}

close $fileToRead

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

close $fileToWrite