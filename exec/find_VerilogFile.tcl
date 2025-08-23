#!/usr/bin/env tclsh

set outputfile "./list/rtl_design.tcl";
set fileToWrite [open $outputfile w];

proc find_HDLfiles {path} {
   set flist{};

   if {[file isdirectory $path]} {
    set path [file normalize $path];
    proc recursivefind {current_dir} {
        set HDL_filelist{};
        set current_hdlfile [glob -nocomplain -types f -directory $current_dir -- *.v *.sv *.vhdl];

        foreach fileToAdd current_hdlfile {
          lappend HDL_filelist $fileToAdd;  
        }
        

        set subdirectory [glob -nocomplain -types d -directory  $current_dir -- *];
        foreach SubdirCurrent $subdirectory {
         set HDLinCurrentSubdir  [recursivefind $SubdirCurrent];
         set  HDL_filelist [$HDL_filelist  $current_hdlfile];
        }
       return  HDL_filelist;
    };
           
   } else {
     error "这不是一个文件夹: $path";
   };
    

    set flist [find_HDLfiles $path]
    return $flist;#要接收，不可以直接用
}




set flist [find_HDLfiles [pwd]];
puts "找到了[llength $flist]个Verilog/SystemVerilog/VHDL文件";
foreach f [lsort -dictionary $flist] {
    puts $f
};