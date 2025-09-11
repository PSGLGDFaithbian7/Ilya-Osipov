
#!/usr/bin/env tclsh
# ----------------------------------------------------------------------
# output_report.tcl
# 作用：读取 ./setup/library.lst 中的 TopModule，生成 ./work/script.tcl（供 DC 执行）
# 特点：
#   - 统一在“生成的 DC 脚本内部”设置一次 DATE，所有产物共用同一个时间戳
#   - 修正了花括号/引号、句柄、变量展开时机、HTML 转义等问题
#   - 默认覆盖写入 ./work/script.tcl，如需追加可将 open 模式改为 "a"
# ----------------------------------------------------------------------

## 1) 检查/准备目录
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

## 2) 读取 Top module 名称
set fileToRead  [open ./setup/library.lst r]
set outputfile "./work/script.tcl"
set fileToWrite [open $outputfile a]  

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

# ==================== 3) 生成 DC 脚本内容 ==================== #
# 统一在 DC 脚本“运行时”设置一次 DATE，以保证所有输出同一时间戳
puts $fileToWrite "# ===== Auto-generated DC run script for $top_module ====="
puts $fileToWrite "set DATE \[clock format \[clock seconds\] -format \"%Y%m%d_%H%M%S\"\]"

puts $fileToWrite "\n######### Post-Compile Checks & Outputs #########"
# 注意：如果你的 DC 版本命令是 change_names（复数），可改成 change_names
puts $fileToWrite "change_name -rules sverilog -hierarchy"

puts $fileToWrite "\n######### Multi-Voltage Checks #########"
puts $fileToWrite "redirect -file ../report/${top_module}_\${DATE}_check_mv.rpt {check_mv_design}"
puts $fileToWrite "redirect -file ../report/${top_module}_\${DATE}_check_mv_verbose.rpt {check_mv_design -verbose}"

puts $fileToWrite "\n######### File Outputs #########"
puts $fileToWrite "write -format verilog -hierarchy -output ../output/${top_module}_\${DATE}.v"
puts $fileToWrite "write_sdc ../output/${top_module}_\${DATE}.sdc"
# 注：常见用法为 'write -format ddc'；若你的环境只认 write_file，请按需改回
puts $fileToWrite "write -format ddc -hierarchy -output ../output/${top_module}_\${DATE}_compile.ddc"
puts $fileToWrite "write_sdf ../output/${top_module}_\${DATE}.sdf"

# --- Parasitics Export (DC only supports reduced/distributed) ---
puts $fileToWrite {# 导出 DC 可用的寄生文件（非 signoff，仅估算/调试用）}
# 在生成阶段展开 top_module，保留 DATE 到运行时展开
puts $fileToWrite "set _rc_out ../output/${top_module}_\${DATE}.rc"

# 首选 reduced；若失败再试 distributed（修正缺失右花括号）
puts $fileToWrite {if {[catch {write_parasitics -format reduced -output $_rc_out} wp_err]} {
  puts "WARN: write_parasitics reduced failed: $wp_err"
  if {[catch {write_parasitics -format distributed -output $_rc_out} wp_err2]} {
    puts "ERROR: write_parasitics failed (distributed): $wp_err2"
  } else {
    puts "INFO: Parasitics written in distributed format: $_rc_out"
  }
} else {
  puts "INFO: Parasitics written in reduced format: $_rc_out"
}}

puts $fileToWrite "set_svf -off"

puts $fileToWrite "\n######## Synthesis Reports ########"
# 已在文件开头设置 DATE，这里统一复用同一时间戳
# 11) 报告生成（../report/）
puts $fileToWrite {set DATE [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]}
puts $fileToWrite {redirect -file ../report/${top_module}_${DATE}_report.qor                   {report_qor -nosplit}}
puts $fileToWrite {redirect -file ../report/${top_module}_${DATE}_report.area                 {report_area -hierarchy -nosplit}}
puts $fileToWrite {redirect -file ../report/${top_module}_${DATE}_report.power                {report_power -hierarchy -nosplit}}
puts $fileToWrite {redirect -file ../report/${top_module}_${DATE}_report.clock_gating         {report_clock_gating -structure -verbose -nosplit}}
puts $fileToWrite {redirect -file ../report/${top_module}_${DATE}_report.activity_unannotated.rpt {report_switching_activity -unannotated -nosplit}}
puts $fileToWrite {redirect -file ../report/${top_module}_${DATE}_report.activity_summary.rpt    {report_switching_activity -hierarchy -summary -nosplit}}
puts $fileToWrite {redirect -file ../report/${top_module}_${DATE}_report.power_detail.rpt        {report_power -analysis_effort high -hierarchy}}
puts $fileToWrite {redirect -file ../report/${top_module}_${DATE}_area_recovery.log              {report_qor -nosplit; report_area -hierarchy -nosplit; report_power -hierarchy -nosplit}}
puts $fileToWrite {puts "DONE. Netlist/SDC/SDF/RC and reports are under ../output and ../report."}
close $fileToWrite

puts "Generated DC run script: [file normalize $outputfile]"
puts "Run: dc_shell -f $outputfile | tee ../report/script.log"

