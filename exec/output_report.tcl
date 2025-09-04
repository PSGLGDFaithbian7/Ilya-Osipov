#!/usr/bin/env tclsh

## Check/prepare directories
foreach dir {work output report setup} {
    if {![file exists ./$dir]} {
        if {$dir eq "setup"} {
            error "missing ./setup directory"
        } else {
            file mkdir ./$dir
        }
    }
}
if {![file exists ./setup/library.lst]} {
    error "missing ./setup/library.lst"
}

## Timestamp
set DATE [exec date "+%Y%m%d_%H%M"]

## Read Top module name
set fileToRead  [open ./setup/library.lst r]
set fileToWrite [open ./work/script.tcl a]

set top_module ""
while {[gets $fileToRead line] >= 0} {
   set line [string trim $line]
   if {[regexp {^TopModule:\s*(\S+)} $line _ TopModule]} {
       set top_module $TopModule
       break
   }
}
close $fileToRead

if {$top_module eq ""} {
    close $fileToWrite
    error "missing 'TopModule: <name>' entry in ./setup/library.lst"
}

# ==================== Generate Script Content ==================== #
puts $fileToWrite "\n######### Post-Compile Checks & Outputs #########"
puts $fileToWrite "change_name -rules sverilog -hierarchy"

puts $fileToWrite "\n######### Multi-Voltage Checks #########"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_check_mv.rpt {check_mv_design}"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_check_mv_verbose.rpt {check_mv_design -verbose}"

puts $fileToWrite "\n######### File Outputs #########"
puts $fileToWrite "write -format verilog -hierarchy -output ../output/${top_module}_${DATE}.v"
puts $fileToWrite "write_sdc ../output/${top_module}_${DATE}.sdc"
puts $fileToWrite "write_file -format ddc -hierarchy -output ../output/${top_module}_${DATE}_compile.ddc"
puts $fileToWrite "write_sdf ../output/${top_module}_${DATE}.sdf"
puts $fileToWrite "write_parasitics -format spf -output ../output/${top_module}_${DATE}.spf"
puts $fileToWrite "write_parasitics -format spef -output ../output/${top_module}_${DATE}.spef"
puts $fileToWrite "set_svf -off"

puts $fileToWrite "\n######## Synthesis Reports ########"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.timing {check_timing}"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.paths.max {report_timing -path end -delay max -max_paths 200 -nworst 2 -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.paths.min {report_timing -path end -delay min -max_paths 200 -nworst 2 -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.full_paths.max {report_timing -path full -input_pins -nets -transition_time -capacitance -attributes -delay max -max_paths 5 -nworst 2 -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.full_paths.min {report_timing -path full -input_pins -nets -transition_time -capacitance -attributes -delay min -max_paths 5 -nworst 2 -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.constraint_violators {report_constraints -all_violators -verbose -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_MOUDLE}_${DATE}_report.qor {report_qor -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.area {report_area -hierarchy -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.power {report_power -hierarchy -nosplit}"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.clock_gating {report_clock_gating -structure -verbose -nosplit}"

close $fileToWrite