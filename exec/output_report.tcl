#!/usr/bin/env tclsh

## Check/prepare directories
if {![file exists ./work]}  {
    file mkdir ./work
}
if {![file exists ./output]}  {
    file mkdir ./output
}
if {![file exists ./report]}  {
    file mkdir ./report
}

if {![file exists ./setup]} {
    error "missing ./setup directory"
}

if {![file exists ./setup/library.lst]} {
    error "missing ./setup/library.lst"
}

## Timestamp
set DATE [exec date "+%Y%m%d_%H%M"]

## Read Top module name (from setup/library.lst)
set fileToRead  [open ./setup/library.lst r]
# As requested: must be append mode
set fileToWrite [open ./work/script.tcl a]

while {[gets $fileToRead line] >= 0} {
   set line [string trim $line]

   if {[regexp {^TopModule:\s(\S+)$} $line _ TopModule]} {
       set top_module $TopModule
       continue
   }
}

# Error if TopModule not parsed
if {![info exists top_module] || $top_module eq ""} {
    close $fileToRead
    close $fileToWrite
    error "missing 'TopModule: <name>' entry in ./setup/library.lst"
}

# ==================== Generate Design Compiler execution script ==================== #

puts $fileToWrite "#########prep#########"
puts $fileToWrite [join [list "current_design" $top_module] " "]
puts $fileToWrite "change_name -rules sverilog -hierarchy"

puts $fileToWrite "#########mv_check#########"
# Low-power/multi-voltage consistency check (reports in ../report/ with timestamp)
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_check_mv.rpt" "{check_mv_design}"] " "]
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_check_mv_verbose.rpt" "{check_mv_design -verbose}"] " "]

puts $fileToWrite "#########output#########"
# Export gate-level artifacts: netlist / SDC / DDC / SDF / SPF / SPEF
puts $fileToWrite [join [list "write -format verilog -hierarchy -output" "../output/${top_module}_${DATE}.v"] " "]
puts $fileToWrite [join [list "write_sdc" "../output/${top_module}_${DATE}.sdc"] " "]
puts $fileToWrite [join [list "write_file -format ddc -hierarchy -output" "../output/${top_module}_${DATE}_compile.ddc"] " "]
puts $fileToWrite [join [list "write_sdf" "../output/${top_module}_${DATE}.sdf"] " "]
# Export both SPF and SPEF (different -format and file extensions)
puts $fileToWrite [join [list "write_parasitics -format spf  -output" "../output/${top_module}_${DATE}.spf"] " "]
puts $fileToWrite [join [list "write_parasitics -format spef -output" "../output/${top_module}_${DATE}.spef"] " "]
puts $fileToWrite "set_svf -off"

# ==================== Keep only one set of synthesis reports (merged advantages, later parameters take precedence, all with -nosplit) ==================== #
puts $fileToWrite "########reports(one_set)########"

# 1) Design timing health check (overview)
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_report.timing" "{check_timing}"] " "]

# 2) Timing coverage: large number of end-point paths
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_report.paths.max" \
    "{report_timing -path end  -delay max -max_paths 200 -nworst 2 -nosplit}"] " "]
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_report.paths.min" \
    "{report_timing -path end  -delay min -max_paths 200 -nworst 2 -nosplit}"] " "]

# 3) Timing details: few full-paths, including pins/nets/transitions/capacitances/attributes
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_report.full_paths.max" \
    "{report_timing -path full -input_pins -nets -transition_time -capacitance -attributes -delay max -max_paths 5 -nworst 2 -nosplit}"] " "]
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_report.full_paths.min" \
    "{report_timing -path full -input_pins -nets -transition_time -capacitance -attributes -delay min -max_paths 5 -nworst 2 -nosplit}"] " "]

# 4) Constraint violations (Note: DC command is report_constraints (plural))
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_report.constraint_violators" \
    "{report_constraints -all_violators -verbose -nosplit}"] " "]

# 5) QoR overview
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_report.qor" "{report_qor -nosplit}"] " "]

# 6) Reference cell statistics / area / power / clock gating structure
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_report.refs"         "{report_reference -nosplit}"] " "]
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_report.area"         "{report_area -hierarchy -nosplit}"] " "]
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_report.power"        "{report_power -hierarchy -nosplit}"] " "]
puts $fileToWrite [join [list "redirect -file" "../report/${top_module}_${DATE}_report.clock_gating" "{report_clock_gating -structure -verbose -nosplit}"] " "]

close $fileToWrite
close $fileToRead