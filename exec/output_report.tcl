#!/usr/bin/env tclsh

##检查
if {![file exists ./work]}  {
    file mkdir ./work
}

if {![file exists ./setup]} {
    error "missing ./setup directory"
}

if {![file exists ./setup/library.lst]} {
    error "missing ./setup/library.lst"
}

set DATE [exec date "+%Y%m%d_%H%M"]

##读入文件
set fileToRead  [open ./setup/library.lst r]
set fileToWrite [open ./work/script.tcl a]

while {[gets $fileToRead line] >= 0} {
   set line [string trim $line]

    if {[regexp {^TopModule:\s(\S+)$} $line _ TopModule]} {
        set top_module $TopModule
        continue
    }

}


puts $fileToWrite "#########output#########"
puts $fileToWrite [join [list "write -format verilog -hierarchy -output" "../output/${top_module}_${DATE}.v"] " "]
puts $fileToWrite [join [list "write_sdc" "../output/${top_module}_${DATE}.sdc"] " "]
puts $fileToWrite [join [list "write_file -format ddc -hierarchy -output" "../output/${top_module}_${DATE}_compile.ddc"] " "]
puts $fileToWrite [join [list "write_sdf" "../output/${top_module}_${DATE}.sdf"] " "]
puts $fileToWrite "set_svf -off"

puts $fileToWrite "########report########"
puts $fileToWrite [join [list "report_area -nosplit -hierarchy" ">" "../report/${top_module}_${DATE}_area.rpt"] " "]
puts $fileToWrite [join [list "report_qor" ">" "../report/${top_module}_${DATE}_qor.rpt"] " "]
puts $fileToWrite [join [list "report_timing -max_paths 10000" ">" "../report/${top_module}_${DATE}_report_timing.rpt"] " "]
puts $fileToWrite [join [list "report_constraint -all_violators -nosplit" ">" "../report/${top_module}_${DATE}_report_constraint.rpt"] " "]
puts $fileToWrite [join [list "report_power" ">" "../report/${top_module}_${DATE}_power.rpt"] " "]

close $fileToWrite
close $fileToRead


