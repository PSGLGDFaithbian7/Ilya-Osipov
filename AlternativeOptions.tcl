
#=============================================================================#
#                                DFT Insertion                                #
#=============================================================================#
if {$WITH_DFT} {
    # DFT Signal Type Definitions
    set_dft_signal -view spec         -type ScanEnable  -port scan_enable -active_state 1
    set_dft_signal -view existing_dft -type ScanEnable  -port scan_enable -active_state 1
    set_dft_signal -view spec         -type Constant    -port scan_mode   -active_state 1
    set_dft_signal -view existing_dft -type Constant    -port scan_mode   -active_state 1
    set_dft_signal -view existing_dft -type ScanClock   -port dco_clk     -timing [list 45 55]
    set_dft_signal -view existing_dft -type ScanClock   -port lfxt_clk    -timing [list 45 55]
    set_dft_signal -view existing_dft -type Reset       -port reset_n     -active 0

    # DFT Configuration
    
    set_dft_insertion_configuration -preserve_design_name true
    
    ##scan type
    set_scan_configuration -style multiplexed_flip_flop
    set_scan_configuration -clock_mixing mix_clocks
    set_scan_configuration -chain_count 3

    # DFT Test Protocol Creation
    create_test_protocol

    # DFT Design Rule Check
    redirect -tee -file ./results/report_dft_drc.txt           {dft_drc}
    redirect      -file ./results/report_dft_drc_verbose.txt   {dft_drc -verbose}
    redirect      -file ./results/report_dft_drc_coverage.txt  {dft_drc -coverage_estimate}
    redirect      -file ./results/report_dft_scan_config.txt   {report_scan_configuration}
    redirect      -file ./results/report_dft_insert_config.txt {report_dft_insertion_configuration}
    
    # Preview DFT insertion
    redirect -tee -file ./results/report_dft_preview.txt       {preview_dft}
    redirect      -file ./results/report_dft_preview_all.txt   {preview_dft -show all -test_points all}

    # DFT insertion
    insert_dft

    # DFT Incremental Compile
    compile_ultra -scan -incremental

    # DFT Coverage estimate
    redirect -file ./results/report.dft_drc_coverage.txt  {dft_drc -coverage_estimate}
}



########################################################################
# Part 1 — create_generated_clock（严格落到真实 CK/Q 引脚）
# 目标：为 div_2_inst/clk_25m_reg 的 Q 引脚定义由 $CLK 二分频生成的时钟 $CLK_M
########################################################################

# === 配置：按你的设计实际路径/名字修改这三项 ===
set CLK        CLK                   ;# 顶层已存在的母钟名（假设已在别处 create_clock）
set CLK_M      CLK_M                 ;# 生成时钟名
set DIV2_FF    div_2_inst/clk_25m_reg

# 期望的 CK/Q 引脚全路径（强烈建议用全路径，避免通配符误选）
set DIV2_CK    ${DIV2_FF}/CK
set DIV2_Q     ${DIV2_FF}/Q

# === 检查母钟是否存在（仅提示，不强制） ===
set master_clk_obj [get_clocks -quiet $CLK]
if { [llength $master_clk_obj] != 1 } {
  puts "WARN: Master clock '$CLK' not found (count=[llength $master_clk_obj])."
  puts "      确认是否已在顶层对 [get_ports -quiet $CLK] 执行 create_clock。"
}

# === 解析 CK/Q 引脚（严格匹配，不使用模糊通配） ===
set ck_pin [get_pins -quiet $DIV2_CK]
set q_pin  [get_pins -quiet $DIV2_Q]

# 如未唯一命中，尝试使用 -hier 的保底搜索（仅做一次兜底，不建议长期依赖）
if { [llength $ck_pin] != 1 || [llength $q_pin] != 1 } {
  puts "INFO: 精确路径未唯一命中，尝试分层搜索兜底……"
  if { [llength $ck_pin] != 1 } {
    set ck_pin [get_pins -hier -quiet *clk_25m_reg*/CK]
  }
  if { [llength $q_pin] != 1 } {
    set q_pin  [get_pins -hier -quiet *clk_25m_reg*/Q]
  }
}

# 最终必须唯一命中，否则报错中止
if { [llength $ck_pin] != 1 || [llength $q_pin] != 1 } {
  puts "ERROR: 无法唯一定位分频触发器的 CK/Q 引脚。"
  puts "  CK candidates: $ck_pin"
  puts "  Q  candidates: $q_pin"
  error "请核对实例名与层级路径（推荐使用准确全路径而非通配符）。"
}

# === 如果同名生成时钟已存在，仅提示（避免重复创建失败） ===
set existed_gen [get_clocks -quiet $CLK_M]
if { [llength $existed_gen] >= 1 } {
  puts "WARN: 生成时钟 '$CLK_M' 已存在，将跳过创建。"
} else {
  # 强烈建议：-source 指到“该分频触发器看到的母钟位置”——即 CK 引脚
  create_generated_clock -name $CLK_M \
                         -source $ck_pin \
                         -divide_by 2 \
                         $q_pin
  puts "INFO: 已创建 generated clock '$CLK_M'：-source=$ck_pin target=$q_pin divide_by=2"
}

# === 快速校验 ===
catch { report_generated_clocks } _
catch { report_clocks -attributes [get_clocks -quiet $CLK_M] } _



########################################################################
# Part 3 — set_dont_touch for ICG cells
# 目标：锁定若干 ICG 实例，防止综合/优化改写（保留门控拓扑）
########################################################################

# === 列表中放“准确全路径”的 ICG 实例名 ===
set ICG_LIST {
  DLLA_top_inst/u_mlp_top/u_weight_sram/u_u0_sram_clk_icg
  DLLA_top_inst/u_mlp_top/u_weight_sram/u_u1_sram_clk_icg
  DLLA_top_inst/u_mlp_top/u_weight_sram/u_u2_sram_clk_icg
  DLLA_top_inst/u_mlp_top/u_weight_sram/u_u3_sram_clk_icg
  DLLA_top_inst/u_mlp_top/u_weight_sram/u_u4_sram_clk_icg
  DLLA_top_inst/u_mlp_top/u_weight_sram/u_u5_sram_clk_icg
  DLLA_top_inst/u_mlp_top/u_weight_sram/u_u6_sram_clk_icg
  DLLA_top_inst/u_mlp_top/u_weight_sram/u_u7_sram_clk_icg
}

set applied {}
set missing {}
foreach icg $ICG_LIST {
  set c [get_cells -quiet $icg]
  if { [llength $c] == 1 } {
    # 仅锁 cell，自由留给后端在网络上插 buffer/clone（利于 CTS 控偏斜）
    set_dont_touch $c
    lappend applied $icg
  } elseif { [llength $c] == 0 } {
    lappend missing $icg
  } else {
    puts "WARN: ICG '$icg' 命中多个对象：$c"
    lappend missing $icg
  }
}

puts "INFO: 已对 [llength $applied] 个 ICG 设置 dont_touch："
puts "      $applied"
if { [llength $missing] > 0 } {
  puts "WARN: 下列 ICG 未找到或多重匹配，请核对层级路径："
  puts "      $missing"
}

# 可选：报告这些单元的关键属性，便于确认
catch { report_cell [get_cells -quiet $ICG_LIST] } _
