#!/usr/bin/env tclsh
#检查
if {![file exists ./work]}  {
    file mkdir ./work
}

if {![file exists ./setup]} {
    error "missing ./setup directory"
}

if {![file exists ./setup/rst.lst]} {
    error "missing ./setup/rst.lst"
}

set DATE [exec date "+%Y%m%d_%H%M"]
set fileToRead  [open ./setup/rst.lst r]
set fileToWrite [open ./work/script.tcl a]

puts $fileToWrite "######### Set Reset (for dc_shell -t) ###########"

set RST_NAME {};

while {[gets $fileToRead line] >= 0} {
   set line [string trim $line]
    
    if {[regexp {^ResetName\d:\s(\S+)$} $line _ ResetName]} {
        lappend RST_NAME $ResetName
       
    }

}

 puts $fileToWrite "set_dont_touch_network 				\[get_ports [list {*}$RST_NAME]\]"
 puts $fileToWrite "set_false_path -from   				\[get_ports [list {*}$RST_NAME]\]" 
 puts $fileToWrite "set_ideal_network -no_propagate     \[get_ports [list {*}$RST_NAME]\]"
 puts $fileToWrite "set_drive 0            				\[get_ports [list {*}$RST_NAME]\]"
        
close $fileToWrite
close $fileToRead
