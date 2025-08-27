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
foreach file {setup/io.lst setup/clk.lst} {
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
    set fileToRead     [open ./setup/io.lst r]
    set fileToWrite    [open ./work/script.tcl a]
    set ClockToRecord  [open ./setup/clk.lst r]
} err]} {
    errorExit "无法打开文件: $err"
}

# 收集时钟端口
set ClockPort_List {}
while {[gets $ClockToRecord line1] >= 0} {
    set line1 [string trim $line1]
    if {[string match "#*" $line1] || $line1 eq ""} continue

    set items1 [split $line1 "|"]
    set clean_items1 {}
    foreach item $items1 {
        set item [string trim $item]
        if {[regexp {^[^:]+:\s*(.*)$} $item -> value]} {
            lappend clean_items1 [string trim $value]
        } else {
            lappend clean_items1 $item
        }
    }

    set ClockPort [string trim [lindex $clean_items1 4]]
    if {$ClockPort ne ""} {
        lappend ClockPort_List $ClockPort
    }
}

# 处理 io.lst
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

    if {[llength $clean_items] < 7} {
        errorExit "io.lst 行格式错误，缺少字段: $line"
    }

    lassign $clean_items Direction IO_Port Clock_Name MAX_DELAY MIN_DELAY MAX_DELAY_O MIN_DELAY_O

    # 校验字段
    if {$Direction ni {I O 0}} {
        errorExit "无效的 Direction 值: '$Direction'，应为 I, O 或 0，在 io.lst 中，行: $line"
    }
    if {$IO_Port eq "" && $Direction ne "0"} {
        errorExit "IO_Port 不能为空（除非 Direction 为 0）: 在 io.lst 中，行: $line"
    }
    if {$Clock_Name eq ""} {
        errorExit "Clock_Name 不能为空: 在 io.lst 中，行: $line"
    }
    if {$IO_Port in $ClockPort_List} {
        errorExit "IO_Port '$IO_Port' 与时钟端口冲突: 在 io.lst 中，行: $line"
    }

    foreach var {MAX_DELAY MIN_DELAY MAX_DELAY_O MIN_DELAY_O} {
        set value [set $var]
        if {$value ne "" && ![string is double -strict $value]} {
            errorExit "无效的 $var 值: '$value' 在 io.lst 中，行: $line"
        }
    }

    # 输出约束命令

    puts "--------------I/O Delay--------------"
    puts "clock : $Clock_Name"
    puts "port  : $IO_Port"
    puts $fileToWrite "######## Set I/O ########"
    if {$Direction != "0" && $IO_Port != "0"} {
        if {$Direction eq "I"} {
            if {$MAX_DELAY ne ""} {
                puts $fileToWrite "set_input_delay $MAX_DELAY -max -clock \[get_clocks $Clock_Name\] \[get_ports $IO_Port\]"
                puts "max_input_delay : $MAX_DELAY"
            }
            if {$MIN_DELAY ne ""} {
                puts $fileToWrite "set_input_delay $MIN_DELAY -min -clock \[get_clocks $Clock_Name\] \[get_ports $IO_Port\]"
                puts "min_input_delay : $MIN_DELAY"
            }
        } elseif {$Direction eq "O"} {
            if {$MAX_DELAY_O ne ""} {
                puts $fileToWrite "set_output_delay $MAX_DELAY_O -max -clock \[get_clocks $Clock_Name\] \[get_ports $IO_Port\]"
                puts "max_output_delay : $MAX_DELAY_O"
            }
            if {$MIN_DELAY_O ne ""} {
                puts $fileToWrite "set_output_delay $MIN_DELAY_O -min -clock \[get_clocks $Clock_Name\] \[get_ports $IO_Port\]"
                puts "min_output_delay : $MIN_DELAY_O"
            }
        }
        puts $fileToWrite ""
    } else {
        set clockPorts [join $ClockPort_List " "]
        if {$MAX_DELAY ne ""} {
            puts $fileToWrite "set_input_delay $MAX_DELAY -max -clock \[get_clocks $Clock_Name\] \[remove_from_collection \[all_inputs\] \[get_ports {$clockPorts}\]\]"
            puts "max_input_delay : $MAX_DELAY"
        }
        if {$MIN_DELAY ne ""} {
            puts $fileToWrite "set_input_delay $MIN_DELAY -min -clock \[get_clocks $Clock_Name\] \[remove_from_collection \[all_inputs\] \[get_ports {$clockPorts}\]\]"
            puts "min_input_delay : $MIN_DELAY"
        }
        if {$MAX_DELAY_O ne ""} {
            puts $fileToWrite "set_output_delay $MAX_DELAY_O -max -clock \[get_clocks $Clock_Name\] \[all_outputs\]"
            puts "max_output_delay : $MAX_DELAY_O"
        }
        if {$MIN_DELAY_O ne ""} {
            puts $fileToWrite "set_output_delay $MIN_DELAY_O -min -clock \[get_clocks $Clock_Name\] \[all_outputs\]"
            puts "min_output_delay : $MIN_DELAY_O"
        }
        puts $fileToWrite ""
    }
}

# 其他约束
puts $fileToWrite "set_max_fanout 32 \[current_design\]"

# 关闭文件
foreach f [list $fileToRead $fileToWrite $ClockToRecord] {
    catch {close $f}
}
