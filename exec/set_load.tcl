#!/usr/bin/env tclsh

# 错误退出函数
proc errorExit {message} {
    puts stderr "错误: $message"
    exit 1
}

# 安全的文件关闭函数
proc safeClose {fileHandle} {
    if {[catch {close $fileHandle} err]} {
        puts stderr "警告: 关闭文件时出错: $err"
    }
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

# 从 library.lst 一次性读取：TopModule / LibraryFile_WC / WorstCondition
if {![file exists ./setup/library.lst]} {
    errorExit "缺少 ./setup/library.lst 文件"
}

if {[catch {set fh_lib [open ./setup/library.lst r]} err]} {
    errorExit "无法打开 ./setup/library.lst 文件: $err"
}

# 初始化变量
set LibraryFileWC ""
set WorstCondition ""
set top_module ""

while {[gets $fh_lib line] >= 0} {
    set line [string trim [lindex [split $line "#"] 0]]
    if {$line eq ""} { continue }

    if {[regexp {^LibraryFile_WC:\s*(\w+)(?:\.db)?$} $line -> v]} {
        set LibraryFileWC [string trim $v]
        continue
    }
    if {[regexp {^WorstCondition:\s*(.+)$} $line -> v]} {
        set WorstCondition [string trim $v]
        continue
    }
    if {[regexp -nocase {^TopModule:\s*(\S+)$} $line -> tm]} {
        set top_module $tm
        continue
    }
}

set full_library_path "${LibraryFileWC}.db"  ;# 假设 .db 是默认后缀
if {[catch {read_lib $full_library_path} err]} {
    puts "Error: Failed to read library $full_library_path: $err"
    exit 1
}
safeClose $fh_lib

# 必填项检查
if {$LibraryFileWC eq ""} {
    errorExit "在 ./setup/library.lst 中未找到 LibraryFile_WC（示例：LibraryFile_WC: <libname>）"
}
if {$WorstCondition eq ""} {
    errorExit "在 ./setup/library.lst 中未找到 WorstCondition（示例：WorstCondition: <cond>）"
}
if {$top_module eq ""} {
    errorExit "在 ./setup/library.lst 中未找到 TopModule（应为：'TopModule: <name>'）"
}

set LIB_WC_NAME $LibraryFileWC
set WCCOM       $WorstCondition

# 检查文件存在性
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
    if {[string match "#*" $line1] || $line1 eq ""} {
        continue}
    
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

    # 确保有足够的字段
    if {[llength $clean_items1] >= 5} {
        set ClockPort [string trim [lindex $clean_items1 4]]
        if {$ClockPort ne "" && $ClockPort ne "0"} {
            lappend ClockPort_List $ClockPort
        }
    }
}
safeClose $ClockToRecord

# 写入脚本头部信息
puts $fileToWrite "# Generated on: $DATE"
puts $fileToWrite "# Top Module: $top_module"
puts $fileToWrite "# Library: $LIB_WC_NAME"
puts $fileToWrite "# Worst Condition: $WCCOM"
puts $fileToWrite ""

# 处理 io.lst
set line_number 0
while {[gets $fileToRead line] >= 0} {
    incr line_number
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
        errorExit "io.lst 第 $line_number 行格式错误，缺少字段: $line"
    }

    # 使用显式赋值替代lassign，提高可读性
    set Direction      [lindex $clean_items 0]
    set IO_Port        [lindex $clean_items 1]
    set Clock_Name     [lindex $clean_items 2]
    set MAX_DELAY      [lindex $clean_items 3]
    set MIN_DELAY      [lindex $clean_items 4]
    set MAX_DELAY_O    [lindex $clean_items 5]
    set MIN_DELAY_O    [lindex $clean_items 6]

    # 校验字段
    if {$Direction ni {I O 0}} {
        errorExit "无效的 Direction 值: '$Direction'，应为 I, O 或 0，在 io.lst 第 $line_number 行"
    }
    if {$IO_Port eq "" && $Direction ne "0"} {
        errorExit "IO_Port 不能为空（除非 Direction 为 0），在 io.lst 第 $line_number 行"
    }
    if {$Clock_Name eq ""} {
        errorExit "Clock_Name 不能为空，在 io.lst 第 $line_number 行"
    }
    if {$IO_Port ne "" && $IO_Port in $ClockPort_List} {
        errorExit "IO_Port '$IO_Port' 与时钟端口冲突，在 io.lst 第 $line_number 行"
    }

    # 验证数值字段
    foreach {var_name var_value} [list MAX_DELAY $MAX_DELAY MIN_DELAY $MIN_DELAY MAX_DELAY_O $MAX_DELAY_O MIN_DELAY_O $MIN_DELAY_O] {
        if {$var_value ne "" && ![string is double -strict $var_value]} {
            errorExit "无效的 $var_name 值: '$var_value'，在 io.lst 第 $line_number 行"
        }
    }

    # 输出约束命令
    puts "--------------I/O Delay--------------"
    puts "clock : $Clock_Name"
    puts "port  : $IO_Port"
    puts $fileToWrite "######## Set I/O ########"

    if {$Direction ne "0" && $IO_Port ne "0" && $IO_Port ne ""} {
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
        # 对全体输入/输出施加默认约束
        if {[llength $ClockPort_List] > 0} {
            set clockPorts [join $ClockPort_List " "]
            if {$MAX_DELAY ne ""} {
                puts $fileToWrite "set_input_delay $MAX_DELAY -max -clock \[get_clocks $Clock_Name\] \[remove_from_collection \[all_inputs\] \[get_ports {$clockPorts}\]\]"
                puts "max_input_delay : $MAX_DELAY"
            }
            if {$MIN_DELAY ne ""} {
                puts $fileToWrite "set_input_delay $MIN_DELAY -min -clock \[get_clocks $Clock_Name\] \[remove_from_collection \[all_inputs\] \[get_ports {$clockPorts}\]\]"
                puts "min_input_delay : $MIN_DELAY"
            }
        } else {
            if {$MAX_DELAY ne ""} {
                puts $fileToWrite "set_input_delay $MAX_DELAY -max -clock \[get_clocks $Clock_Name\] \[all_inputs\]"
                puts "max_input_delay : $MAX_DELAY"
            }
            if {$MIN_DELAY ne ""} {
                puts $fileToWrite "set_input_delay $MIN_DELAY -min -clock \[get_clocks $Clock_Name\] \[all_inputs\]"
                puts "min_input_delay : $MIN_DELAY"
            }
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

# 写入环境约束
puts $fileToWrite ""
puts $fileToWrite "######## Env Constraints ########"

puts $fileToWrite ""
puts $fileToWrite "# Output load (pF)"
puts $fileToWrite "set_load 5 \[all_outputs\]"

puts $fileToWrite ""
puts $fileToWrite "# High-fanout modeling (Synopsys DC)"
puts $fileToWrite "set_app_var high_fanout_net_threshold 60"
puts $fileToWrite "set_app_var high_fanout_net_pin_capacitance 0.01"

puts $fileToWrite ""
puts $fileToWrite "# Wire-load model selection"
puts $fileToWrite {set_wire_load_mode "segmented"}
puts $fileToWrite {set_wire_load_selection "WireAreaLowkCon"}

puts $fileToWrite ""
puts $fileToWrite "# Operating conditions "
puts $fileToWrite "set_operating_conditions -max $WCCOM -max_library $LIB_WC_NAME"

puts $fileToWrite ""
puts $fileToWrite "# Examples (commented):"
puts $fileToWrite "# set_drive 0.1125 \[all_inputs\]            ;# 约等于 LVCMOS18 16mA => 0.1125 kΩ"
puts $fileToWrite "# set_input_transition 2 \[all_inputs\]       ;# 输入上升/下降沿 (ns)，请按实际修改"

# 安全关闭文件
safeClose $fileToRead
safeClose $fileToWrite

