#!/usr/bin/env tclsh
#检查
if {![file exists ./work]}  {
    file mkdir ./work
}

if {![file exists ./setup]} {
    error "missing ./setup directory"
}

if {![file exists ./setup/rtl_design.lst]} {
    error "missing ./setup/rtl_design.lst"
}

if {![file exists ./setup/library.lst]} {
    error "missing ./setup/library.lst"
}


#打开文件

set DATE [exec date "+%Y%m%d_%H%M"]
set fileToRead1  [open ./setup/library.lst r]
set fileToWrite [open ./work/script.tcl a]
set fileToRead2 [open ./setup/rtl_design.lst r]
puts $fileToWrite "######### Read Design (for dc_shell -t) ###########"

#读入文件
while {[gets $fileToRead2 line] >= 0} {
    # 去掉 # 注释及两端空白
    set line [string trim [lindex [split $line "#"] 0]]

    if {[regexp -nocase {^(\S+\.v)$} $line _ filepath]} {
        puts $fileToWrite "analyze -format verilog [list $filepath]"
        continue
    }
   
    if {[regexp -nocase {^(\S+\.vhdl)$} $line _ filepath]} {
        puts $fileToWrite "analyze -format VHDL [list $filepath]"
        continue
    }
   

    if {[regexp -nocase {^(\S+\.sv)$} $line _ filepath]} {
        puts $fileToWrite "analyze -format system verilog [list $filepath]"
        continue
    }
   
}


while {[gets $fileToRead1 line] >= 0} {
   set line [string trim $line]

    if {[regexp {^TopModule:\s(\S+)$} $line _ TopModule]} {
        set top_module $TopModule
        break
    }

}

puts $fileToWrite "elaborate [list $top_module]"
puts $fileToWrite "uniquify -force "
puts $fileToWrite "check_design"
puts $fileToWrite "link"
set output_file [file join ".." "output" "${top_module}_${DATE}_link.ddc"]
puts $fileToWrite "write_file -format ddc -hierarchy -output $output_file"


close $fileToWrite
close $fileToRead1
close $fileToRead2

