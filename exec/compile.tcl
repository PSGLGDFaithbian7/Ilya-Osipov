#!/usr/bin/env tclsh

##choose script to write
set outputfile "./work/script.tcl";
set fileToWrite [open $outputfile a];

puts $fileToWrite "********************Compile*******************";
puts $fileToWrite "compile_ultra";

close $fileToWrite;