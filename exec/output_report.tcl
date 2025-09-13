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

## Timestamp (baked into generated file names)
set DATE [exec date "+%Y%m%d_%H%M"]

## Read Top module name
set fileToRead  [open ./setup/library.lst r]
set fileToWrite [open ./work/script.tcl a]
fconfigure $fileToWrite -encoding utf-8 -translation lf

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
# —— 注意：以下字符串中的 ${top_module} 与 ${DATE} 在“生成阶段”即被替换为固定值 —— #

# ---------------- Multi-Voltage Checks ----------------
puts $fileToWrite "\n# ---------------- Multi-Voltage Checks ----------------"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_check_mv.rpt          { check_mv_design }"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_check_mv_verbose.rpt  { check_mv_design -verbose }"

# ---------------- Reports (QoR/Area/Power/CG) ----------------
file mkdir ../report
# 已于上方生成 power_summary，这里保留一份常规合集
redirect -file ../report/${top_module}_${DATE}_report.qor             { report_qor -nosplit }
redirect -file ../report/${top_module}_${DATE}_report.area            { report_area -hierarchy -nosplit }
redirect -file ../report/${top_module}_${DATE}_report.power           { report_power -hierarchy -analysis_effort high -nosplit }
redirect -file ../report/${top_module}_${DATE}_report.clock_gating    { report_clock_gating -structure -verbose -nosplit }

# Add from script2: more detailed timing reports
redirect -file ../report/${top_module}_${DATE}_report.timing         {check_timing}
redirect -file ../report/${top_module}_${DATE}_report.paths.max      {report_timing -path end  -delay max -max_paths 200 -nworst 2}
redirect -file ../report/${top_module}_${DATE}_report.full_paths.max {report_timing -path full -input_pins -nets -transition_time -capacitance -attributes -delay max -max_paths 5 -nworst 2}
redirect -file ../report/${top_module}_${DATE}_report.paths.min      {report_timing -path end  -delay min -max_paths 200 -nworst 2}
redirect -file ../report/${top_module}_${DATE}_report.full_paths.min {report_timing -path full -input_pins -nets -transition_time -capacitance -attributes -delay min -max_paths 5 -nworst 2}
redirect -file ../report/${top_module}_${DATE}_report.refs           {report_reference}

# ---------------- Outputs (Netlist/SDC/SDF/Parasitics) ----------------
change_names -rules sverilog -hierarchy
write      -format verilog -hierarchy -output ../output/${top_module}_${DATE}.v
write_sdc  ../output/${top_module}_${DATE}.sdc
write      -format ddc     -hierarchy -output ../output/${top_module}_${DATE}_compile.ddc
write_sdf  ../output/${top_module}_${DATE}.sdf

# Parasitic (non-signoff)
set _rc_out ../output/${top_module}_${DATE}.rc
if {[catch {write_parasitics -format reduced     -output $_rc_out} wp_err]} {
  puts "WARN: write_parasitics reduced failed: $wp_err"
  if {[catch {write_parasitics -format distributed -output $_rc_out} wp_err2]} {
    puts "ERROR: write_parasitics failed (distributed): $wp_err2"
  } else {
    puts "INFO: Parasitics written in distributed format: $_rc_out"
  }
} else {
  puts "INFO: Parasitics written in reduced format: $_rc_out"
}

# Add from script2: check_mv_design
check_mv_design > ../report/${top_module}_${DATE}_check_mv_design.txt
check_mv_design -verbose > ../report/${top_module}_${DATE}_check_mv_verbose_design.txt


# Close SVF
set_svf -off

# Quick summary bundle
redirect -file ../report/${top_module}_${DATE}_area_recovery.log {
  report_qor -nosplit
  report_area -hierarchy -nosplit
  report_power -hierarchy -analysis_effort high -nosplit
}

puts "DONE. Netlist/SDC/SDF/RC and reports are under ../output and ../report."

close $fileToWrite
