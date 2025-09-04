#!/usr/bin/env tclsh

set outputfile "./work/script.tcl"
set fileToWrite [open $outputfile a]

puts $fileToWrite "\n#============================================================================#"
puts $fileToWrite "#                                Synthesize                                   #"
puts $fileToWrite "#============================================================================#"

puts $fileToWrite {# Prevent assignment statements in the Verilog netlist.}
puts $fileToWrite {set_fix_multiple_port_nets -feedthrough}
puts $fileToWrite {set_fix_multiple_port_nets -all -buffer_constants}

puts $fileToWrite "\n# Power optimization settings"
puts $fileToWrite {set_leakage_optimization true}
puts $fileToWrite {set_dynamic_optimization true}

puts $fileToWrite "\n# DesignWare settings"
puts $fileToWrite {set_app_var dw_prefer_mc_inside true}

puts $fileToWrite "\n# Area constraint (0 means optimize for timing)"
puts $fileToWrite {set_max_area 0}

puts $fileToWrite "\n# Structuring and mapping effort"
puts $fileToWrite {set_flatten false}
puts $fileToWrite {set_structure true -timing true -boolean false}

puts $fileToWrite {
# Final check before compiling
set cd_status [redirect ./report/report.check_beforecompile {check_design}]
if {$cd_status != 0} {
    puts "Check Design Error before compile!"
    exit
} else {
    puts "Check Design Pass before compile!"
}
}

puts $fileToWrite "\n#********************Compile*******************}"
puts $fileToWrite {compile_ultra -no_autoungroup -no_seq_output_inversion -no_boundary_optimization}

close $fileToWrite