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
puts $fileToWrite "\n# ---------------- Reports (QoR/Area/Power/CG) ----------------"
puts $fileToWrite "file mkdir ../report"
puts $fileToWrite "# 已于上方生成 power_summary，这里保留一份常规合集"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.qor             { report_qor -nosplit }"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.area            { report_area -hierarchy -nosplit }"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.power           { report_power -hierarchy -analysis_effort high -nosplit }"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_report.clock_gating    { report_clock_gating -structure -verbose -nosplit }"

# ---------------- Outputs (Netlist/SDC/SDF/Parasitics) ----------------
puts $fileToWrite "\n# ---------------- Outputs (Netlist/SDC/SDF/Parasitics) ----------------"
puts $fileToWrite "change_names -rules sverilog -hierarchy"
puts $fileToWrite "write      -format verilog -hierarchy -output ../output/${top_module}_${DATE}.v"
puts $fileToWrite "write_sdc  ../output/${top_module}_${DATE}.sdc"
puts $fileToWrite "write      -format ddc     -hierarchy -output ../output/${top_module}_${DATE}_compile.ddc"
puts $fileToWrite "write_sdf  ../output/${top_module}_${DATE}.sdf"

# Parasitic (non-signoff)
puts $fileToWrite "\n# Parasitic (non-signoff)"
puts $fileToWrite "set _rc_out ../output/${top_module}_${DATE}.rc"
puts $fileToWrite "if {[catch {write_parasitics -format reduced     -output \$_rc_out} wp_err]} {"
puts $fileToWrite "  puts \"WARN: write_parasitics reduced failed: \$wp_err\""
puts $fileToWrite "  if {[catch {write_parasitics -format distributed -output \$_rc_out} wp_err2]} {"
puts $fileToWrite "    puts \"ERROR: write_parasitics failed (distributed): \$wp_err2\""
puts $fileToWrite "  } else {"
puts $fileToWrite "    puts \"INFO: Parasitics written in distributed format: \$_rc_out\""
puts $fileToWrite "  }"
puts $fileToWrite "} else {"
puts $fileToWrite "  puts \"INFO: Parasitics written in reduced format: \$_rc_out\""
puts $fileToWrite "}"

# Close SVF
puts $fileToWrite "\n# Close SVF"
puts $fileToWrite "set_svf -off"

# Quick summary bundle
puts $fileToWrite "\n# Quick summary bundle"
puts $fileToWrite "redirect -file ../report/${top_module}_${DATE}_area_recovery.log {"
puts $fileToWrite "  report_qor -nosplit"
puts $fileToWrite "  report_area -hierarchy -nosplit"
puts $fileToWrite "  report_power -hierarchy -analysis_effort high -nosplit"
puts $fileToWrite "}"
puts $fileToWrite ""
puts $fileToWrite "puts \"DONE. Netlist/SDC/SDF/RC and reports are under ../output and ../report.\""

close $fileToWrite
