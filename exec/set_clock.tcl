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

foreach file {setup/clk.lst} {
    if {![file exists ./$file]} {
        errorExit "缺少 ./$file 文件"
    }
}

if {[catch {set DATE [exec date "+%Y%m%d_%H%M"]} err]} {
    set DATE [clock format [clock seconds] -format "%Y%m%d_%H%M"]
}

if {[catch {
    set fileToWrite [open ./work/script.tcl a]
    set fileToRead [open ./setup/clk.lst r]
} err]} {
    errorExit "无法打开文件: $err"
}

set ClockPort_List {}
set ClockName_List {}

while {[gets $fileToRead line] >= 0} {
    if {![string match "#*" $line] && [string trim $line] ne ""} continue
    set items [split [string trim $line] "|"]
    set clean_items [lmap item $items {string trim $item}]
    lassign $clean_items ClockName Peroid Rise Fall ClockPort
    
set CLK_SKEW              	[expr $Peroid*0.05]
set CLK_SOURCE_LATENCY   	[expr $Peroid*0.1]    
set CLK_NETWORK_LATENCY   	[expr $Peroid*0.1]  
set CLK_TRAN             	[expr $Peroid*0.01]
set INPUT_DELAY_MAX             [expr $Peroid*0.4]
set INPUT_DELAY_MIN             0
set OUTPUT_DELAY_MAX            [expr $Peroid*0.4]
set OUTPUT_DELAY_MIN            0


puts "----------------clk------------------"
puts "Clock: $ClockName"
puts "Peroid_value: ${Peroid}"

     if {[string first "/" $ClockPort] >= 0} {
   
        puts $fp_write "########CLOCK#########"
        puts $fp_write "create_clock -name $ClockName    \[get_pins -hierarchical $ClockPort\] -period $Peroid -waveform \[list $Rise $Fall\]"
        puts $fp_write "set_dont_touch_network    \[get_pins -hierarchical $ClockPort\]"
        puts $fp_write "set_ideal_network -no_propagate    \[get_pins -hierarchical $ClockPort\]"
   
     } else {
       
        puts $fp_write "########CLOCK#########"
        puts $fp_write "remove_driving_cell      \[get_ports $ClockPort\]" 
        puts $fp_write "set_drive       0        \[get_ports $ClockPort\]"
        puts $fp_write "create_clock -name $CKNAME    \[get_ports $ClockPort\] -period $Peroid -waveform   \[list $Rise $Fall\]"
        puts $fp_write "set_dont_touch_network    $CKNAME"
        puts $fp_write "set_ideal_network -no_propagate    \[get_ports $ClockPort\]"
        lappend ClockPort_list $ClockPort

}

}