#!/usr/bin/env tclsh
# -----------------------------------------------------------------------------
# Enhanced I/O & Env Constraint Generator
# - 标注式正则宽松化：关键字与冒号之间允许任意空格
# - 其余功能不变
# -----------------------------------------------------------------------------

# ------------------------ Helpers ------------------------
proc errorExit {message} {
    puts stderr "错误: $message"
    exit 1
}
proc warn  {message} { puts stderr "警告: $message" }
proc log_info {message} { puts "INFO: $message" }
proc safeClose {fh} {
    if {[catch {close $fh} err]} { puts stderr "警告: 关闭文件时出错: $err" }
}

# ------------------------ Config toggles ------------------------
set ENABLE_SET_UNITS                1
set ENABLE_STRICT_LIB_REQUIRED      0
set ENABLE_SET_OPERATING_CONDITIONS 0

# ------------------------ Defaults ------------------------
set DEFAULT_LOAD_PF                5
set DEFAULT_HIGH_FANOUT_THRESHOLD 60
set DEFAULT_HIGH_FANOUT_PIN_CAP    0.01
set DEFAULT_WIRE_LOAD_MODE        "segmented"
set DEFAULT_WIRE_LOAD_SELECTION   "WireAreaLowkCon"

# ------------------------ Paths ------------------------
set OUTPUT_SCRIPT "./work/script.tcl"
set LIBLIST_FILE  "./setup/library.lst"
set IO_LIST       "./setup/io.lst"
set CLK_LIST      "./setup/clk.lst"

# ------------------------ Ensure dirs/files ------------------------
foreach dir {work setup} {
    if {![file exists ./$dir]} {
        if {$dir eq "work"} {
            if {[catch {file mkdir ./$dir} err]} { errorExit "无法创建 ./$dir 目录: $err" }
        } else { errorExit "缺少 ./$dir 目录" }
    }
}
if {![file exists $LIBLIST_FILE]} { errorExit "缺少 $LIBLIST_FILE 文件" }

# ------------------------ Parse library.lst ------------------------
if {[catch {set fh_lib [open $LIBLIST_FILE r]} err]} {
    errorExit "无法打开 $LIBLIST_FILE 文件: $err"
}
set LibraryPaths {}; set Incdirs {}; set LibraryFile ""; set LibraryFileWC ""
set WorstCondition ""; set SyntheticLibrary ""; set LinkLibraryFile ""; set TopModule ""
set DefaultLoadPf ""

while {[gets $fh_lib raw] >= 0} {
    set line [string trim [lindex [split $raw "#"] 0]]
    if {$line eq ""} { continue }
    if {[regexp -nocase {^TopModule:\s*(\S+)}        $line -> v]} { set TopModule $v;       continue }
    if {[regexp -nocase {^Incdir:\s*(\S+)}            $line -> v]} { lappend Incdirs $v;     continue }
    if {[regexp -nocase {^LibraryPath:\s*(\S+)}       $line -> v]} { lappend LibraryPaths $v; continue }
    if {[regexp -nocase {^LibraryFile:\s*(\S+)}       $line -> v]} { set LibraryFile $v;     continue }
    if {[regexp -nocase {^LibraryFile_WC:\s*(\S+)}    $line -> v]} { set LibraryFileWC $v;   continue }
    if {[regexp -nocase {^WorstCondition:\s*(\S+)}    $line -> v]} { set WorstCondition $v;  continue }
    if {[regexp -nocase {^SyntheticLibrary:\s*(\S+)}  $line -> v]} { set SyntheticLibrary $v; continue }
    if {[regexp -nocase {^LinkLibraryFile:\s*(\S+)}   $line -> v]} { set LinkLibraryFile $v; continue }
    if {[regexp -nocase {^DefaultLoad_pf:\s*([0-9.]+)} $line -> v]} { set DefaultLoadPf $v;  continue }
}
safeClose $fh_lib
if {$TopModule eq ""}      { warn "未在 $LIBLIST_FILE 中找到 TopModule" }
if {$WorstCondition eq ""} { warn "未在 $LIBLIST_FILE 中找到 WorstCondition" }
if {$DefaultLoadPf ne ""}  { set DEFAULT_LOAD_PF $DefaultLoadPf }

# ------------------------ Library resolving ------------------------
proc unique_list {lst} {
    array set seen {}
    set out {}
    foreach x $lst { if {![info exists seen($x)]} { set seen($x) 1; lappend out $x } }
    return $out
}
proc resolve_lib {spec searchDirs} {
    set tryExts {.db .lib .db.gz}
    set candidates {}; set ext [file extension $spec]
    set hasDir [expr {[file dirname $spec] ne "." && [file dirname $spec] ne ""}]
    set basename [file tail $spec]

    if {$ext ne ""} {
        if {$hasDir} { lappend candidates $spec }
        lappend candidates [file join "../lib" $basename]
        foreach d $searchDirs { lappend candidates [file join $d $basename] }
    } else {
        foreach e $tryExts {
            lappend candidates [file join "../lib" "${spec}$e"]
            foreach d $searchDirs { lappend candidates [file join $d "${spec}$e"] }
        }
        foreach d [concat [list "../lib"] $searchDirs] {
            foreach m [glob -nocomplain -types f -directory $d "${spec}*.db*"] { lappend candidates $m }
            foreach m [glob -nocomplain -types f -directory $d "${spec}*.lib*"] { lappend candidates $m }
        }
    }
    set candidates [unique_list $candidates]
    set found ""
    foreach c $candidates { if {[file exists $c]} { set found $c; break } }
    set libname ""
    if {$found ne ""} { set libname [file rootname [file tail $found]] }
    return [list $found $libname $candidates]
}

set searchDirs $LibraryPaths
set wc_found ""; set LIB_WC_NAME ""
if {$LibraryFileWC ne ""} {
    lassign [resolve_lib $LibraryFileWC $searchDirs] wc_found LIB_WC_NAME wc_tried
    if {$wc_found eq ""} {
        set msg "未找到 LibraryFile_WC '$LibraryFileWC'。已尝试: $wc_tried"
        if {$ENABLE_STRICT_LIB_REQUIRED} { errorExit $msg } else { warn $msg }
    } else {
        log_info "最差条件库: $wc_found (逻辑名: $LIB_WC_NAME)"
        if {[string match "*.db.gz" $wc_found]} { warn "发现 .db.gz，实际使用前需解压为 .db" }
    }
} else { warn "未指定 LibraryFile_WC" }

set link_found ""; set LINK_LIB_NAME ""
if {$LinkLibraryFile ne ""} {
    lassign [resolve_lib $LinkLibraryFile $searchDirs] link_found LINK_LIB_NAME link_tried
    if {$link_found eq ""} {
        warn "未找到 LinkLibraryFile '$LinkLibraryFile'。已尝试: $link_tried"
    } else { log_info "链接库: $link_found" }
}

# ------------------------ Check IO/CLK files and open output ------------------------
foreach f [list $IO_LIST $CLK_LIST] {
    if {![file exists $f]} { errorExit "缺少 $f 文件" }
}
if {[catch {
    set fh_io  [open $IO_LIST r]
    set fh_clk [open $CLK_LIST r]
    set fh_out [open $OUTPUT_SCRIPT a]
} err]} { errorExit "无法打开必要文件: $err" }

# ------------------------ Timestamp and header ------------------------
if {[catch { set DATE [exec date "+%Y%m%d_%H%M"] }]} {
    set DATE [clock format [clock seconds] -format "%Y%m%d_%H%M"]
}
puts $fh_out "# 生成时间: $DATE"
puts $fh_out "# 顶层模块: $TopModule"
puts $fh_out "# 最差条件: $WorstCondition"
puts $fh_out "# 库(显示名): $LIB_WC_NAME"
puts $fh_out ""
if {$ENABLE_SET_UNITS} {
    puts $fh_out "set_units -time ns -capacitance pF"
    puts $fh_out ""
}

# ------------------------ Collect clock ports from clk.lst ------------------------
set ClockPort_List {}
set ln 0
while {[gets $fh_clk raw] >= 0} {
    incr ln
    set line [string trim [lindex [split $raw "#"] 0]]
    if {$line eq ""} { continue }
    if {[regexp -nocase {Port\s*:\s*([A-Za-z0-9_\[\]/\.]+)} $line -> p]} {
        lappend ClockPort_List $p; continue
    }
    set toks [regexp -inline -all {\S+} $line]
    if {[llength $toks] >= 5} {
        set p [lindex $toks 4]
        if {$p ne "" && $p ne "0"} { lappend ClockPort_List $p }
    }
}
set ClockPort_List [lsort -unique $ClockPort_List]
safeClose $fh_clk

# ------------------------ Process io.lst and emit I/O delays ------------------------
puts $fh_out "##### I/O 延迟与端口约束 #####"
set line_number 0
while {[gets $fh_io raw] >= 0} {
    incr line_number
    set line [string trim [lindex [split $raw "#"] 0]]
    if {$line eq ""} { continue }

    set Direction ""; set IO_Port ""; set Clock_Name ""
    set MAX_DELAY ""; set MIN_DELAY ""; set MAX_DELAY_O ""; set MIN_DELAY_O ""

    # 1. 标注式（宽松正则：关键字与冒号之间允许任意空格）
    if {[regexp -nocase {I/O\s*:\s*([IO0])} $line -> _dir]} {
        set Direction $_dir
        regexp -nocase {I/O_Port\s*:\s*([A-Za-z0-9_\[\]/\.]+)} $line -> _p
        set IO_Port $_p
        regexp -nocase {Clock(Name)?\s*:\s*([A-Za-z0-9_\[\]/\.]+)} $line -> _ _c
        set Clock_Name $_c
        regexp -nocase {max_Delay\s*:\s*([0-9\.]+)}  $line -> _v
        if {[info exist _v]} { set MAX_DELAY $_v }
        regexp -nocase {min_Delay\s*:\s*([0-9\.]+)}  $line -> _v
        if {[info exist _v]} { set MIN_DELAY $_v }
        regexp -nocase {max_Delay_o\s*:\s*([0-9\.]+)} $line -> _v
        if {[info exist _v]} { set MAX_DELAY_O $_v }
        regexp -nocase {min_Delay_o\s*:\s*([0-9\.]+)} $line -> _v
        if {[info exist _v]} { set MIN_DELAY_O $_v }
    } else {
        # 2. 旧版 7 列
        set items [regexp -inline -all {\S+} $line]
        if {[llength $items] < 7} {
            errorExit "io.lst 第 $line_number 行格式错误，需7列或标注式，实际: '$line'"
        }
        set Direction   [lindex $items 0]
        set IO_Port     [lindex $items 1]
        set Clock_Name  [lindex $items 2]
        set MAX_DELAY   [lindex $items 3]
        set MIN_DELAY   [lindex $items 4]
        set MAX_DELAY_O [lindex $items 5]
        set MIN_DELAY_O [lindex $items 6]
    }

    if {$Direction ni {"I" "O" "0"}} {
        errorExit "无效的 Direction 值: '$Direction'，应为 I/O/0，在 io.lst 第 $line_number 行"
    }
    if {$Clock_Name eq ""} { errorExit "Clock_Name 不能为空，在 io.lst 第 $line_number 行" }
    if {$IO_Port eq "" && $Direction ne "0"} {
        errorExit "IO_Port 不能为空（除非 Direction 为 0），在 io.lst 第 $line_number 行"
    }
    foreach {var_name var_value} [list MAX_DELAY $MAX_DELAY MIN_DELAY $MIN_DELAY MAX_DELAY_O $MAX_DELAY_O MIN_DELAY_O $MIN_DELAY_O] {
        if {$var_value ne "" && ![string is double -strict $var_value]} {
            errorExit "无效的 $var_name 值: '$var_value'，在 io.lst 第 $line_number 行"
        }
    }

    puts $fh_out "###### 设置 I/O （行:$line_number）"
    if {$Direction ne "0" && $IO_Port ne ""} {
        if {$Direction eq "I"} {
            if {$MAX_DELAY ne ""} {
                puts $fh_out "set_input_delay $MAX_DELAY -max -clock \[get_clocks $Clock_Name\] \[get_ports $IO_Port\]"
            }
            if {$MIN_DELAY ne ""} {
                puts $fh_out "set_input_delay $MIN_DELAY -min -clock \[get_clocks $Clock_Name\] \[get_ports $IO_Port\]"
            }
        } elseif {$Direction eq "O"} {
            if {$MAX_DELAY_O ne ""} {
                puts $fh_out "set_output_delay $MAX_DELAY_O -max -clock \[get_clocks $Clock_Name\] \[get_ports $IO_Port\]"
            }
            if {$MIN_DELAY_O ne ""} {
                puts $fh_out "set_output_delay $MIN_DELAY_O -min -clock \[get_clocks $Clock_Name\] \[get_ports $IO_Port\]"
            }
        }
        puts $fh_out ""
    } else {
        set clockPorts [join $ClockPort_List " "]
        if {[llength $ClockPort_List]} {
            if {$MAX_DELAY ne ""} {
                puts $fh_out "set_input_delay $MAX_DELAY -max -clock \[get_clocks $Clock_Name\] \[remove_from_collection \[all_inputs\] \[get_ports \{$clockPorts\}\]\]"
            }
            if {$MIN_DELAY ne ""} {
                puts $fh_out "set_input_delay $MIN_DELAY -min -clock \[get_clocks $Clock_Name\] \[remove_from_collection \[all_inputs\] \[get_ports \{$clockPorts\}\]\]"
            }
        } else {
            if {$MAX_DELAY ne ""} {
                puts $fh_out "set_input_delay $MAX_DELAY -max -clock \[get_clocks $Clock_Name\] \[all_inputs\]"
            }
            if {$MIN_DELAY ne ""} {
                puts $fh_out "set_input_delay $MIN_DELAY -min -clock \[get_clocks $Clock_Name\] \[all_inputs\]"
            }
        }
        if {$MAX_DELAY_O ne ""} {
            puts $fh_out "set_output_delay $MAX_DELAY_O -max -clock \[get_clocks $Clock_Name\] \[all_outputs\]"
        }
        if {$MIN_DELAY_O ne ""} {
            puts $fh_out "set_output_delay $MIN_DELAY_O -min -clock \[get_clocks $Clock_Name\] \[all_outputs\]"
        }
        puts $fh_out ""
    }
}
safeClose $fh_io

# ------------------------ Env constraints ------------------------
puts $fh_out ""
puts $fh_out "######## 环境约束 ########"
puts $fh_out ""
puts $fh_out "# 输出负载 (pF)"
puts $fh_out "set_load $DEFAULT_LOAD_PF \[all_outputs\]"
puts $fh_out ""
puts $fh_out "# 高扇出建模 (Synopsys DC)"
puts $fh_out "set_app_var high_fanout_net_threshold $DEFAULT_HIGH_FANOUT_THRESHOLD"
puts $fh_out "set_app_var high_fanout_net_pin_capacitance $DEFAULT_HIGH_FANOUT_PIN_CAP"
puts $fh_out ""
puts $fh_out "# 线负载模型选择"
puts $fh_out "set_wire_load_mode \"$DEFAULT_WIRE_LOAD_MODE\""
puts $fh_out "set_wire_load_selection \"$DEFAULT_WIRE_LOAD_SELECTION\""
puts $fh_out ""

# ------------------------ Operating conditions (optional) ------------------------
if {$ENABLE_SET_OPERATING_CONDITIONS} {
    if {$wc_found ne "" && $LIB_WC_NAME ne "" && $WorstCondition ne ""} {
        puts $fh_out "# 工作条件"
        puts $fh_out "set_operating_conditions -max $WorstCondition -max_library $LIB_WC_NAME"
        puts $fh_out ""
    } else {
        warn "未能设置 set_operating_conditions（缺少库或 WorstCondition）"
    }
}

# ------------------------ Examples & tips ------------------------
puts $fh_out "# 示例（按需启用）："
puts $fh_out "# set_drive 0.1125 \[all_inputs\]        ;# ~ LVCMOS18 16mA => 0.1125 kΩ"
puts $fh_out "# set_input_transition 2 \[all_inputs\]   ;# 输入上升/下降沿 (ns)，按实际修改"
puts $fh_out ""

safeClose $fh_out
log_info "约束已追加写入: $OUTPUT_SCRIPT"
# -----------------------------------------------------------------------------
