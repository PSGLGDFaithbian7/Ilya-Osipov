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

puts $fileToWrite  {
##############################################################################
#  完整体系（含 power 子目录）
#  ../report/<YYYYMMDD_HHMMSS>/{timing,power,area,clock,mv}
#  ../output/<YYYYMMDD_HHMMSS>/{verilog,sdc,ddc,sdf,parasitics}
##############################################################################

set DATE [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
set repRoot "../report/$DATE"
set outRoot "../output/$DATE"

foreach dir [list \
    $repRoot/timing  $repRoot/power  $repRoot/area  $repRoot/clock  $repRoot/mv \
    $outRoot/verilog $outRoot/sdc    $outRoot/ddc   $outRoot/sdf    $outRoot/parasitics] {
    file mkdir $dir
}

# ------------------------------------------------------------------
# 1. 报告输出（含 power 子目录）
# ------------------------------------------------------------------
# 基本 QoR / 面积 / 功耗 / 时钟门控
redirect -file $repRoot/area/${top_module}_report.qor          { report_qor -nosplit }
redirect -file $repRoot/area/${top_module}_report.area         { report_area -hierarchy -nosplit }
redirect -file $repRoot/power/${top_module}_report.power       { report_power -hierarchy -analysis_effort high -nosplit }
redirect -file $repRoot/clock/${top_module}_report.clock_gating { report_clock_gating -structure -verbose -nosplit }

# ---- power 额外报告（融入体系） ----
redirect -file $repRoot/power/${top_module}_power_summary.rpt {
  report_power -hier -analysis_effort high -nosplit
}
if_cmd report_switching_activity -hierarchy -summary -nosplit

# Multi-Voltage
redirect -file $repRoot/mv/${top_module}_check_mv.rpt          { check_mv_design }
redirect -file $repRoot/mv/${top_module}_check_mv_verbose.rpt  { check_mv_design -verbose }

# 详细时序
redirect -file $repRoot/timing/${top_module}_timing_setup.rpt {
  report_timing -delay_type max -max_paths 50 -path full_clock_expanded -sort_by slack -nosplit
}
redirect -file $repRoot/timing/${top_module}_timing_hold.rpt {
  report_timing -delay_type min -max_paths 50 -path full_clock_expanded -sort_by slack -nosplit
}
redirect -file $repRoot/timing/${top_module}_constraints_violators.rpt {
  report_constraints -all_violators -nosplit
}
redirect -file $repRoot/clock/${top_module}_clocks.rpt {
  report_clocks -attributes -nosplit
}
redirect -file $repRoot/clock/${top_module}_clock_trees.rpt {
  report_clock_trees -verbose -nosplit
}
redirect -file $repRoot/clock/${top_module}_clock_gating_detailed.rpt {
  report_clock_gating -verbose -nosplit
}

# ------------------------------------------------------------------
# 2. 网表/约束/SDF/寄生参数 输出
# ------------------------------------------------------------------
change_names -rules sverilog -hierarchy

write -format verilog -hierarchy -output $outRoot/verilog/${top_module}.v
write_sdc  $outRoot/sdc/${top_module}.sdc
write -format ddc -hierarchy -output $outRoot/ddc/${top_module}_compile.ddc
write_sdf  $outRoot/sdf/${top_module}.sdf

# 寄生
set _rc_out $outRoot/parasitics/${top_module}.rc
set wp_err [catch {write_parasitics -format reduced -output $_rc_out}]
if {$wp_err} {
    puts "WARN: write_parasitics reduced failed"
    set wp_err2 [catch {write_parasitics -format distributed -output $_rc_out}]
    if {$wp_err2} {
        puts "ERROR: write_parasitics distributed also failed"
    } else {
        puts "INFO: Parasitics written in distributed format: $_rc_out"
    }
} else {
    puts "INFO: Parasitics written in reduced format: $_rc_out"
}

# ------------------------------------------------------------------
# 3. 收尾
# ------------------------------------------------------------------
set_svf -off
redirect -file $repRoot/${top_module}_area_recovery.log {
  report_qor -nosplit
  report_area -hierarchy -nosplit
  report_power -hierarchy -analysis_effort high -nosplit
}

puts "DONE. Reports -> $repRoot ;  Outputs -> $outRoot"
}

close $fileToWrite
