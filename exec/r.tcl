remove_design -all

set_host_options -max_cores 16


set DESIGN_NAME      "Top_multiplier"

set WITH_DFT 0

catch {sh mkdir results}
set sh_output_log_file "./results/logfile.log"

set_svf ./results/$DESIGN_NAME.svf


#=============================================================================#
#                                Configuration                                #
#=============================================================================#
# Enable/Disable DC_ULTRA option
set WITH_DFT 0
# set search_path "\
#     /data/pdk/UMC40LP/IP/G-9LT-LOGIC_MIXED_MODE40N-LP_UMK40LSCLP11BDH-LIBRARY_TAPE_OUT_KIT-Ver.A03_PB/synopsys/ \
#     /data/pdk/UMC40LP/IP/G-9LT-LOGIC_MIXED_MODE40N-LP_UMK40GIOLP25MVSRFS-LIBRARY_TAPE_OUT_KIT-Ver.C03_PB/synopsys \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/minpower/syn \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/libraries/syn \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/dw/syn_ver \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/dw/ \
#     /data/pdk/UMC40LP/IP/G-9LT-LOGIC_MIXED_MODE40N-LP_UMK40GIOLP25MVIRFS-LIBRARY_TAPE_OUT_KIT/synopsys \
#     ../memory/SHLL40_6656X16X1CM16/db \
#     ../memory/SYLL40_56X32X1CM2/db \
#     ../memory/SYLL40_56X16X1CM2/db \
#     ../rtl/include "

# set search_path "\
#     /data/pdk/UMC40LP/G-01-LOGIC_MIXED_MODE40N-LP-DSM-UPDATE1008/IP/G-9LT-LOGIC_MIXED_MODE40N-LP_UMK40LSCLP11BDH-LIBRARY_TAPE_OUT_KIT-Ver.A03_PB/UMK40LSCLP11BDH_A03_TAPEOUTKIT/synopsys \ 
#     /data/pdk/UMC40LP/G-01-LOGIC_MIXED_MODE40N-LP-DSM-UPDATE/IP/G-9LT-LOGIC_MIXED_MODE40N-LP_UMK40GIOLP25MVIRFS-LIBRARY_TAPE_OUT_KIT-Ver.C03_PB/UMK40GIOLP25MVIRFS_C03_TAPEOUTKIT/synopsys/ \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/minpower/syn \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/libraries/syn \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/dw/syn_ver \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/dw/ \
#     ../memory/SHLL40_6656X16X1CM16/db \
#     ../memory/SYLL40_56X32X1CM2/db \
#     ../memory/SYLL40_56X16X1CM2/db \
#     ../rtl/include "


set search_path "\
    /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/minpower/syn \
    /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/libraries/syn \
    /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/dw/syn_ver \
    /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/dw/ \
    /data/pdk/UMC22N/IP/6_Track_Generic_Core_Gate_Length_30n/TP/fsn0u_jrd/2023Q3v1.2/GENERIC_CORE/FrontEnd/synopsys/synthesis/ \
    /data/pdk/UMC22N/IP/6_Track_Generic_Core_Gate_Length_30n/TP/fsn0u_jrd/2023Q3v1.2/GENERIC_CORE/FrontEnd/synopsys/symbol/ \ 
    /data/pdk/UMC28/SC/arm/umc/l28hpcp/sc7mcpp140z_base_svt_c30/r0p2/db \
    /data/pdk/UMC28/SC/arm/umc/l28hpcp/sc7mcpp140z_base_hvt_c35/r0p2/sdb"




# set search_path "\
#     /data/pdk/UMC40LP/G-01-LOGIC_MIXED_MODE40N-LP-DSM-UPDATE/IP/G-9LT-LOGIC_MIXED_MODE40N-LP_UMK40LSCLP11BDH-LIBRARY_TAPE_OUT_KIT-Ver.A03_PB/UMK40LSCLP11BDH_A03_TAPEOUTKIT/synopsys/ \
#     /data/pdk/UMC40LP/G-9LT-LOGIC_MIXED_MODE40N-LP_SC_IO/IO/G-9LT-LOGIC_MIXED_MODE40N-LP_UMK40GIOLP25MVSRFS-LIBRARY_TAPE_OUT_KIT-Ver.C03_PB/synopsys \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/minpower/syn \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/libraries/syn \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/dw/syn_ver \
#     /data/cad/synopsys/dc/syn/O-2018.06-SP5-5/dw/ \
#     /data/pdk/UMC40LP/G-9LT-LOGIC_MIXED_MODE40N-LP_SC_IO/G-9LT-LOGIC_MIXED_MODE40N-LP_UMK40GIOLP25MVIRFS-LIBRARY_TAPE_OUT_KIT/synopsys \
#     ../memory/SHLL40_6656X16X1CM16/db \
#     ../memory/SYLL40_56X32X1CM2/db \
#     ../memory/SYLL40_56X16X1CM2/db \
#     ../rtl/include "
    # /data/pdk/UMC40LP/G-01-LOGIC_MIXED_MODE40N-LP-DSM-UPDATE/IP/G-9LT-LOGIC_MIXED_MODE40N-LP_UMK40LSCLP11BDH-LIBRARY_TAPE_OUT_KIT-Ver.A03_PB/UMK40LSCLP11BDH_A03_TAPEOUTKIT/synopsys/ \
    # /data/pdk/UMC40LP/G-9LT-LOGIC_MIXED_MODE40N-LP_SC_IO/IO/G-9LT-LOGIC_MIXED_MODE40N-LP_UMK40GIOLP25MVSRFS-LIBRARY_TAPE_OUT_KIT-Ver.C03_PB/synopsys \
#=============================================================================#
#                           Read technology library                           #
#=============================================================================#
# Define worst case library
set LIB_WC_FILE   "sc7mcpp140z_l28hpcp_base_svt_c30_tt_ctypical_max_0p90v_25c.db"
set LIB_WC_NAME   "sc7mcpp140z_l28hpcp_base_svt_c30_tt_ctypical_max_0p90v_25c.db:sc7mcpp140z_l28hpcp_base_svt_c30_tt_ctypical_max_0p90v_25c"


# Define worst case IO Pad library
set LIB_IO_WC_FILE   "uk40giolp25mvirfs_297c125_wc.db"
set LIB_IO_WC_NAME   "uk40giolp25mvirfs_162c125_wc.db:uk40giolp25mvirfs_162c125_wc uk40giolp25mvsrfs_162c125_ss.db:uk40giolp25mvsrfs_162c125_ss"


# Define worst case memory library
set LIB_MEM_WC_FILE  "SFLA40_512X20BW64_ss0p99v125c.db \
                    SYLL40_512X20X1CM8_ss0p99v125c.db "

set LIB_MEM_WC_NAME  "SFLA40_512X20BW64_ss0p99v125c.db:SFLA40_512X20BW64_ss0p99v125c \
                      SYLL40_512X20X1CM8_ss0p99v125c.db:SYLL40_512X20X1CM8_ss0p99v125c"


# Define operating conditions
set LIB_WC_OPCON   "tt_ctypical_max_0p90v_25c"


# Define wire-load model
set MIN_WIRE_LOAD_MODEL "wl10"
set TYP_WIRE_LOAD_MODEL "wl30"
set MAX_WIRE_LOAD_MODEL "wl50"
set WLM1    segmented
set WLM2    enclosed
set WLM3    top


# Define nand2 gate name for aera size calculation
set NAND2_NAME    "NAND2B_X0P5M_A7PP140ZTS_C30"

# set symbol_library
# set symbol_library "uk40lsclp11bdh.sdb \ uk40giolp25mvirfs.sdb"
set symbol_library "sc7mcpp140z_l28hpcp_base_hvt_c35.sdb"

set synthetic_library "dw_foundation.sldb \ dw_minpower.sldb"
# Set target_library and link_library  worst
##only for zonghe
##一般为standard cell library & io cell library 的type；是DC在mapping时将设计映射到特定工艺所使用的库，就是使用目标库中的元件综合成设计的门级网表�??
set target_library "$LIB_WC_FILE "
##all library
set link_library   "$LIB_WC_FILE  $synthetic_library *" 




#=============================================================================#
#                               Read design RTL                               #
#=============================================================================#


set RTL_SOURCE_FILES {                   
                            ../rtl/Top_multiplier.v
                            ../rtl/multiplier.v
					 }



catch {sh mkdir WORK}
define_design_lib WORK -path ./WORK
analyze -format sverilog $RTL_SOURCE_FILES
elaborate $DESIGN_NAME

current_design $DESIGN_NAME
uniquify
link

# set auto_insert_level_shifters_on_clocks all
# set mv_insert_level_shifters_on_ideal_nets all

###area power suggest dont
# set_dont_use [get_lib_cells */LAM2UM]

redirect ./results/report.check_rtl {check_design}
# Check design structure after reading verilog
if {[check_design] == 0} {
    puts "Check Design Error!"
    exit;
} else {
    puts "Check Design Pass!"
}



#=============================================================================#
#                           Set design constraints                            #
#=============================================================================#

##############################################################################
#                                                                            #
#                            CLOCK DEFINITION                                #
#                                                                            #
##############################################################################

set INPUT_DELAY_FACTOR 0.5
set OUTPUT_DELAY_FACTOR 0.2
###hold set safety factor higher is safer but not necessary
set CLOCK_UNCERTAINTY_FACTOR 0.1

set CLOCK_PERIOD 4;  #250Mhz

# step1: clk and reset
set CLK clk
set RST_N rst_n

create_clock -name     $CLK   \
             -period   $CLOCK_PERIOD  \
             -waveform "[expr $CLOCK_PERIOD/2] $CLOCK_PERIOD" \
             [get_ports $CLK]


set_ideal_network -no_propagate [get_clocks $CLK]
set_dont_touch_network [get_clocks $CLK]
set_clock_uncertainty [expr $CLOCK_PERIOD * $CLOCK_UNCERTAINTY_FACTOR] [get_clocks $CLK]

## DON'T GET the hierarchy pin, SHOULD get the real PIN like clk_25m_reg/Q 
# create_generated_clock -name $CLK_M \
#                        -source [get_ports $CLK] \
#                        -divide_by 2 \
#                        [get_pins div_2_inst/clk_25m_reg/Q]

###clk rst_n dont touch

# set_ideal_network -no_propagate [get_clocks $CLK_M]
# set_dont_touch_network [get_clocks $CLK_M]
# set_clock_uncertainty [expr $CLOCK_PERIOD * $CLOCK_UNCERTAINTY_FACTOR] [get_clocks $CLK_M]

# set_dont_touch [get_cells {DLLA_top_inst/u_mlp_top/u_weight_sram/u_u0_sram_clk_icg}]
# set_dont_touch [get_cells {DLLA_top_inst/u_mlp_top/u_weight_sram/u_u1_sram_clk_icg}]
# set_dont_touch [get_cells {DLLA_top_inst/u_mlp_top/u_weight_sram/u_u2_sram_clk_icg}]
# set_dont_touch [get_cells {DLLA_top_inst/u_mlp_top/u_weight_sram/u_u3_sram_clk_icg}]
# set_dont_touch [get_cells {DLLA_top_inst/u_mlp_top/u_weight_sram/u_u4_sram_clk_icg}]
# set_dont_touch [get_cells {DLLA_top_inst/u_mlp_top/u_weight_sram/u_u5_sram_clk_icg}]
# set_dont_touch [get_cells {DLLA_top_inst/u_mlp_top/u_weight_sram/u_u6_sram_clk_icg}]
# set_dont_touch [get_cells {DLLA_top_inst/u_mlp_top/u_weight_sram/u_u7_sram_clk_icg}]




# set_false_path -from [get_clocks $CLK] -to [get_clocks $CLK_M]


###add hold and setup time safety
###  my add set_clock_transition
#set_clock_transition 0.3 [get_clocks $CLK]

###bu ba zhe ge jiaru zong WNS fangzhi yingxiang biede
set_false_path -from [get_ports $RST_N]
# set_false_path -from [get_ports $CLK] -to [get_ports clk_out_opad]
set_dont_touch_network [get_ports $RST_N]

# set_dont_touch_network [get_pins rst_s2_reg/Q]

# step2: io contraints
set clk_input_ports "rst_n A_in[*] B_in[*]"

###set_up time
##if max min is not asserted they are same
set_input_delay \
    [expr $CLOCK_PERIOD * $INPUT_DELAY_FACTOR] -max \
    -clock [get_clocks $CLK] \
    [get_ports $clk_input_ports]

set_input_delay \
    0 -min \
    -clock [get_clocks $CLK] \
    [get_ports $clk_input_ports]

set clk_output_ports "out[*]"
##after sometime outputvalue is stable
set_output_delay \
    [expr $CLOCK_PERIOD * $OUTPUT_DELAY_FACTOR] -max \
    -clock [get_clocks $CLK] \
    [get_ports $clk_output_ports]

set_output_delay \
    0 -min \
    -clock [get_clocks $CLK] \
    [get_ports $clk_output_ports]

# # input driving strength Kohm
# # according to FPGA IO standard(LVCMOS18, driving strength=16mA)
# set_drive 0.1125 [get_ports $clk_input_ports]
# set_input_transition 2 [get_ports $clk_M_input_ports]
# set_input_transition 2 [get_ports $clk_input_ports]

# set output load(below 20pF)
set_load 5 [get_port $clk_output_ports]

set high_fanout_net_threshold 60
set high_fanout_net_pin_capacitance 0.01



#=============================================================================#
#              Set operating conditions & wire-load models                    #
#=============================================================================#
# Set operating conditions
set_operating_conditions -max $LIB_WC_OPCON -max_library $LIB_WC_NAME

# # Set wire-load models
#set_wire_load_mode $WLM1
# if {$TC_EN} {
#     set_wire_load_model -name $TYP_WIRE_LOAD_MODEL -max -library $LIB_TC_NAME
# } else {
     #set_wire_load_model -name $MAX_WIRE_LOAD_MODEL -max -library $LIB_WC_NAME
# }

#============================================================================#
#                                Synthesize                                   #
#=============================================================================#

# Prevent assignment statements in the Verilog netlist.
set_fix_multiple_port_nets -feedthrough
set_fix_multiple_port_nets -all -buffer_constants

# Optimize leakage power
set_leakage_optimization true
# Optimize dynamic power
set_dynamic_optimization true

### Configuration
current_design $DESIGN_NAME

#**************************************************************
#Enables the Synopsys Module Compiler to generate arithmetic DesignWare parts.
set dw_prefer_mc_inside true

set_max_area  0

#**************************opt for timing************************************
###logic flatten
#1
set_flatten false  
set_structure true -timing true -boolean false
#****************************************************************************


#Let design compiler set priority to formal verification instead of optimization
#set_app_var simplified_verification_mode true

current_design $DESIGN_NAME
# Synthesis

# insert_clock_gating  clockgating
# set_clock_gating_style -minimum_bitwidth 4 -sequential_cell latch -positive_edge_logic integrated -max_fanout 12

#2
set compile_ultra_ungroup_dw  false


###删除 ip 中没有用到的 port
#remove_unconnected_ports [find -hierarchy cell "*"] 
#remove_unconnected_ports -blast_buses [find -hierarchy cell "*"] 

current_design $DESIGN_NAME
redirect ./results/report.check_beforecompile {check_design}
# Check design structure after reading verilog
if {[check_design] == 0} {
    puts "Check Design Error!"
    exit;
} else {
    puts "Check Design Pass!"
}



# if {$WITH_DFT} {
# 	compile_ultra -scan -no_autoungroup -no_boundary_optimization -gate_clock -inc
#     } 
    # else {
        #3
compile_ultra -no_autoungroup -no_boundary_optimization -gate_clock 
    # }

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



#=============================================================================#
#                            Reports generation                               #
#=============================================================================#

redirect -file ./results/report.timing         {check_timing}
#redirect -file ./results/report.constraints    {report_constraints -all_violators -verbose}
redirect -file ./results/report.paths.max      {report_timing -path end  -delay max -max_paths 200 -nworst 2}
redirect -file ./results/report.full_paths.max {report_timing -path full -input_pins -nets -transition_time -capacitance -attributes -delay max -max_paths 5 -nworst 2}
redirect -file ./results/report.paths.min      {report_timing -path end  -delay min -max_paths 200 -nworst 2}
redirect -file ./results/report.full_paths.min {report_timing -path full -input_pins -nets -transition_time -capacitance -attributes -delay min -max_paths 5 -nworst 2}
redirect -file ./results/report.refs           {report_reference}
redirect -file ./results/report.area           {report_area -hierarchy}
redirect -file ./results/report.power          {report_power -hierarchy}
redirect -file ./results/report.clock_gating   {report_clock_gating -structure -verbose}

# Add NAND2 size equivalent report to the area report file
if {[info exists NAND2_NAME]} {

    set nand2_area [get_attribute [get_lib_cell $LIB_WC_NAME/$NAND2_NAME] area]

    redirect -variable area {report_area}
    regexp {Total cell area:\s+([^\n]+)\n} $area whole_match area
    set nand2_eq [expr $area/$nand2_area]
    set fp [open "./results/report.area" a]
    puts $fp ""
    puts $fp "NAND2 equivalent cell area: $nand2_eq"
    close $fp
    puts ""
    puts "      ======================================================="
    puts "     |                       AREA SUMMARY                    "
    puts "     |-------------------------------------------------------"
    puts "     |"
    puts "     |    $NAND2_NAME cell gate area: $nand2_area"
    puts "     |"
    puts "     |    Total Area                : $area"
    puts "     |    NAND2 equivalent cell area: $nand2_eq"
    puts "     |"
    puts "      ======================================================="
    puts ""
}

#=============================================================================#
#          Dump gate level netlist, final DDC file and Test protocol          #
#=============================================================================#
current_design $DESIGN_NAME

change_name -rules sverilog -hierarchy
check_mv_design > ./results/check_mv_design.txt
check_mv_design -verbose > ./results/check_mv_verbose_design.txt

write -hierarchy -format verilog -output "./results/$DESIGN_NAME.gate.v"
write -hierarchy -format ddc     -output "./results/$DESIGN_NAME.ddc"
write_sdc -nosplit ./results/$DESIGN_NAME.sdc
write_sdf ./results/$DESIGN_NAME.sdf
write_parasitics -output "./results/$DESIGN_NAME.spf"

set_svf -off



