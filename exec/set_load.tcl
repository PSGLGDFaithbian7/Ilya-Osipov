#!/usr/bin/env tclsh

proc errorExit {message} {
    puts stderr "错误: $message"
    exit 1
}

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

foreach file {setup/io.lst setup/clk.lst} {
    if {![file exists ./$file]} {
        errorExit "缺少 ./$file 文件"
    }
}

if {[catch {set DATE [exec date "+%Y%m%d_%H%M"]} err]} {
    set DATE [clock format [clock seconds] -format "%Y%m%d_%H%M"]
}

if {[catch {
    set fileToRead [open ./setup/io.lst r]
    set fileToWrite [open ./work/script.tcl a]
    set ClockToRecord [open ./setup/clk.lst r]
} err]} {
    errorExit "无法打开文件: $err"
}

set ClockPort_List {}

while {[gets $ClockToRecord line1] >= 0} {
    if {[string trim $line1] eq ""} continue
    set items1 [split [string trim $line1] "|"]
    set ClockPort [string trim [lindex $items1 4]]
    if {$ClockPort ne ""} {
        lappend ClockPort_List $ClockPort
    }
}

while {[gets $fileToRead line] >= 0} {
    if {[string trim $line] eq ""} continue
    
    set items [split [string trim $line] "|"]
    set clean_items [lmap item $items {string trim $item}]
    lassign $clean_items Direction IO_Port Clock_Name MAX_DELAY MIN_DELAY MAX_DELAY_O MIN_DELAY_O
    
    if {$Direction != "0" && $IO_Port != "0"} {
        if {$Direction eq "I"} {
            puts $fileToWrite "set_input_delay  $MAX_DELAY -max  -clock \[get_clocks ${Clock_Name}\]  \[get_ports ${IO_Port}\]"
            puts $fileToWrite "set_input_delay  $MIN_DELAY -min  -clock \[get_clocks ${Clock_Name}\]  \[get_ports ${IO_Port}\]"
            puts "--------------I/O Delay--------------"
            puts "clock : ${Clock_Name}"
            puts "port : $IO_Port"
            puts "max_input_delay : $MAX_DELAY"
            puts "min_input_delay : $MIN_DELAY"
        } elseif {$Direction eq "O"} {
            puts $fileToWrite "set_output_delay  $MAX_DELAY_O -max  -clock \[get_clocks ${Clock_Name}\]  \[get_ports ${IO_Port}\]"
            puts $fileToWrite "set_output_delay  $MIN_DELAY_O -min  -clock \[get_clocks ${Clock_Name}\]  \[get_ports ${IO_Port}\]"
            puts "--------------I/O Delay--------------"
            puts "clock : ${Clock_Name}"
            puts "port : $IO_Port"
            puts "max_output_delay : $MAX_DELAY_O"
            puts "min_output_delay : $MIN_DELAY_O"
        }
        puts $fileToWrite ""
    } else {
        # 使用大括号包围时钟端口列表，确保正确处理空格
        set clockPorts [join $ClockPort_List]
        puts $fileToWrite "set_input_delay  $MAX_DELAY -max  -clock \[get_clocks ${Clock_Name}\] \[remove_from_collection \[all_inputs\] \[get_ports $clockPorts\]\]"
        puts $fileToWrite "set_input_delay  $MIN_DELAY -min  -clock \[get_clocks ${Clock_Name}\] \[remove_from_collection \[all_inputs\] \[get_ports $clockPorts\]\]"
        puts $fileToWrite "set_output_delay  $MAX_DELAY_O -max  -clock \[get_clocks ${Clock_Name}\]  \[all_outputs\]"
        puts $fileToWrite "set_output_delay  $MIN_DELAY_O -min  -clock \[get_clocks ${Clock_Name}\]  \[all_outputs\]"
        puts "--------------I/O Delay--------------"
        puts "clock : ${Clock_Name}"
        puts "max_input_delay : $MAX_DELAY"
        puts "min_input_delay : $MIN_DELAY"
        puts "max_output_delay : $MAX_DELAY_O"
        puts "min_output_delay : $MIN_DELAY_O"
        puts $fileToWrite ""
    }
}

puts $fileToWrite "set_max_fanout 32 \[current_design\]"

foreach f [list $fileToRead $fileToWrite $ClockToRecord] {
    catch {close $f}
}