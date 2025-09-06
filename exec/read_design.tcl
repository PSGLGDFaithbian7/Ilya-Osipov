#!/usr/bin/env tclsh
# =============================================================================
# read_design.tcl  (DC-friendly)
# - Parses ./setup/library.lst and ./setup/rtl_design.lst
# - Appends commands to work/script.tcl
# =============================================================================

# ----------- Integrity Checks -----------
if {![file exists ./work]}  { file mkdir ./work }
if {![file exists ./setup]} { error "Missing ./setup directory" }
if {![file exists ./setup/rtl_design.lst]} { error "Missing ./setup/rtl_design.lst" }
if {![file exists ./setup/library.lst]}    { error "Missing ./setup/library.lst" }

set DATE [clock format [clock seconds] -format "%Y%m%d_%H%M"]
set out_script ./work/script.tcl
set fh_out [open $out_script a]

# ----------- Parse library.lst -----------
set fh_lib [open ./setup/library.lst r]
set incdirs {}
set defines {}
set top_module ""

while {[gets $fh_lib line] >= 0} {
    set line [string trim [lindex [split $line "#"] 0]]
    if {$line eq ""} { continue }

    if {[regexp -nocase {^TopModule:\s*(\S+)$} $line -> tm]} {
        set top_module $tm
        continue
    }
    if {[regexp -nocase {^Incdir:\s*(\S.*)$} $line -> idir]} {
        lappend incdirs [string trim $idir]
        continue
    }
    if {[regexp {^\+incdir\+(.+)$} $line -> idir2]} {
        lappend incdirs [string trim $idir2]
        continue
    }
    if {[regexp -nocase {^Define:\s*([A-Za-z_]\w*)(?:=(\S+))?} $line -> dname dval]} {
        if {$dval ne ""} { lappend defines "${dname}=$dval" } else { lappend defines $dname }
        continue
    }
    if {[regexp {^-D([A-Za-z_]\w*)(?:=(\S+))?} $line -> dname2 dval2]} {
        if {$dval2 ne ""} { lappend defines "${dname2}=$dval2" } else { lappend defines $dname2 }
        continue
    }
}
close $fh_lib

if {$top_module eq ""} {
    error "TopModule not found in ./setup/library.lst"
}

# Build analyze options
set inc_arg_vcs ""
if {[llength $incdirs] > 0} {
    set inc_tokens {}
    foreach d $incdirs { lappend inc_tokens "+incdir+$d" }
    set inc_arg_vcs "-vcs \"[join $inc_tokens { }]\""
}
set def_arg ""
if {[llength $defines] > 0} {
    set def_arg "-define [list {*}$defines]"
}

# ----------- Generate Header & WORK library -----------
puts $fh_out "\n######### Read Design (for dc_shell -t) ###########"
puts $fh_out "define_design_lib WORK -path ./work"
puts $fh_out ""

# ----------- Parse rtl_design.lst and generate analyze commands -----------
set fh_rtl [open ./setup/rtl_design.lst r]
while {[gets $fh_rtl line] >= 0} {
    set line [string trim [lindex [split $line "#"] 0]]
    if {$line eq ""} { continue }

    set filepath $line

    if {[regexp -nocase {\.svh$} $filepath]} {
        continue
    }
    if {[regexp -nocase {\.sv$} $filepath] || [regexp -nocase {\.v$} $filepath]} {
        puts $fh_out "analyze -format sverilog $inc_arg_vcs $def_arg [list $filepath]"
        continue
    }
    if {[regexp -nocase {\.vhdl$} $filepath]} {
        puts $fh_out "analyze -format VHDL [list $filepath]"
        continue
    }

    puts $fh_out "# WARN: Unrecognized file extension, skipped: $filepath"
}
close $fh_rtl

# ----------- elaborate / link / uniquify / check / write -----------
puts $fh_out ""
puts $fh_out "elaborate [list $top_module]"
puts $fh_out "current_design [list $top_module]"
puts $fh_out "link"
puts $fh_out "uniquify -force"

puts $fh_out {
if [catch {redirect ../report/report.check_rtl {check_design}} cd_status] {
    puts "Check Design Error: $cd_status"
    exit
} else {
    puts "Check Design Pass!"
}
}

puts $fh_out "\n# ----------- Use for MultiVoltage Design -----------"
puts $fh_out "# set auto_insert_level_shifters_on_clocks all"
puts $fh_out "# set auto_insert_level_shifters_on_nets all"
puts $fh_out "#--------area power suggest dont---------"
puts $fh_out "# set_dont_use \[get_lib_cells */LAP2UM\]\n"

set outdir [file join ".." "output"]
if {![file exists $outdir]} { file mkdir $outdir }
set output_file [file join $outdir "${top_module}_${DATE}_link.ddc"]
puts $fh_out "write_file -format ddc -hierarchy -output [list $output_file]"
close $fh_out

if {[info exists argv0] && $argv0 ne ""} {
    puts "Appended read_design commands to $out_script"
    puts "TopModule: $top_module"
}