#!/usr/bin/env tclsh
#检查
if {![file exists ./work]}  {
    file mkdir ./work
}

if {![file exists ./setup]} {
    error "missing ./setup directory"
}

if {![file exists ./setup/io.lst]} {
    error "missing ./setup/io.lst"
}
if {![file exists ./setup/clk.lst]} {
    error "missing ./setup/clk.lst"
}


set DATE [exec date "+%Y%m%d_%H%M"]
set fileToRead  [open ./setup/io.lst r]
set fileToWrite [open ./work/script.tcl a]
set ClockToRecord [open ./setup/clk.lst r]

set ClockPort_List {}
while {[gets $ClockToRecord line1] >= 0} {
    set items1 [split $line1 "|"]
    foreach item $items1 {
        set clean_item1 [string trim $item1]
    }
    set ClockPort [lindex $clean_item1 4]    
    lappend ClockPort_List $ClockPort

}



while {[gets $fileToRead line] >= 0} {
    set items [split $line "|"]
    foreach item $items {
        set clean_item [string trim $item]
    }
    set Direction [lindex $clean_item 0]    
    set IO_Port [lindex $clean_item 1]    
    set Clock_Name [lindex $clean_item 2]     
    set MAX_DELAY [lindex $clean_item 3] 
    set MIN_DELAY [lindex $clean_item 4]
    set MAX_DELAY_O [lindex $clean_item 5]
    set MIN_DELAY_O [lindex $clean_item 6]

    if {$Direction != "0" && $IO_Port != "0"} {
        if { $DIR == "I" } {
        puts $fileToWrite "set_input_delay  $MAX_DELAY -max  -clock \[get_clocks ${Clock_Name}\]  \[get_ports ${IO_Port}\]"
        puts $fileToWrite "set_input_delay  $MIN_DELAY -min  -clock \[get_clocks ${Clock_Name}\]  \[get_ports ${IO_Port}\]"
  	    puts "--------------I/O Delay--------------"
	    puts "clock : ${Clock_Name} "
	    puts "port : $IO_Port "
	    puts "max_input_delay : $MAX_DELAY "
	    puts "min_input_delay : $MIN_DELAY "
        } elseif { $DIR == "O" } {
            puts $fileToWrite "set_output_delay  $MAX_DELAY_O -max  -clock \[get_clocks ${Clock_Name}\]  \[get_ports ${IO_Port}\]"
            puts $fileToWrite "set_output_delay  $MIN_DELAY_O -min  -clock \[get_clocks ${Clock_Name}\]  \[get_ports ${IO_Port}\]"
  	    puts "--------------I/O Delay--------------"
	    puts "clock : ${Clock_Name} "
	    puts "port : $IO_Port "
	    puts "max_output_delay : $MAX_DELAY_O "
	    puts "min_output_delay : $MIN_DELAY_O "
        }
        puts $fileToWrite ""
    }
} else {
    puts $fileToWrite "set_input_delay  $MAX_DELAY -max  -clock \[get_clocks ${Clock_Name}\] \[remove_from_collection \[all_inputs\] \[get_ports \"${ClockPort_List}\"  \]\] "
    puts $fileToWrite "set_input_delay  $MIN_DELAY -min  -clock \[get_clocks ${Clock_Name}\] \[remove_from_collection \[all_inputs\] \[get_ports \"${ClockPort_List}\"  \]\] "
    puts $fileToWrite "set_output_delay  $MAX_DELAY_O -max  -clock \[get_clocks ${Clock_Name}\]  \[all_outputs\] "
    puts $fileToWrite "set_output_delay  $MIN_DELAY_O -min  -clock \[get_clocks ${Clock_Name}\]  \[all_outputs\] "
    puts "--------------I/O Delay--------------"
	puts "clock : ${Clock_Name} "
	puts "max_input_delay : $MAX_DELAY "
	puts "min_input_delay : $MIN_DELAY "
	puts "max_output_delay : $MAX_DELAY_O "
	puts "min_output_delay : $MIN_DELAY_O "
    puts $fileToWrite ""

}
  
puts $fileToWrite "set_max_fanout 32 \[current_design\]"

close $fileToRead
close $fileToWrite



