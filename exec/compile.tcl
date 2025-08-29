#!/usr/bin/env tclsh

##choose script to write
set outputfile "./work/script.tcl";
set fileToWrite [open $outputfile a];

puts $fileToWrite "#********************Compile*******************";
puts $fp_write "compile_ultra -no_autoungroup -no_seq_output_inversion -no_boundary_optimization -scan -gate_clock"


close $fileToWrite;