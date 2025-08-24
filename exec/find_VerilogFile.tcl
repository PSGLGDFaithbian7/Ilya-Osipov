#!/usr/bin/env tclsh

##检查
if {![file exists ./setup]} {
    error "missing ./setup directory"
}

if {![file exists ./setup/rtl_design.lst]} {
    error "missing ./setup/rtl_design.lst"
}


set outputfile "./setup/rtl_design.lst";
set fileToWrite [open $outputfile w];
fconfigure $fileToWrite -encoding utf-8

##寻找.v文件的函数
proc find_HDLfiles {path} {
   set flist {};#定义列表时列表名后加上空格

   if {[file isdirectory $path]} {
    set path [file normalize $path];
    set flist [recursivefind $path]
    return $flist;#要接收，不可以直接用
           
   } else {
     error "这不是一个文件夹: $path";
   };
}    

#嵌套函数最好定义在外层
proc recursivefind {current_dir} {
        set HDL_filelist {};#定义列表时列表名后加上空格
        set patterns {*.v *.sv *.vhdl *.vh *.svh *.vhd *.V *.SV *.VHDL *.VH *.SVH *.VHD}
        set current_hdlfile [glob -nocomplain -types f -directory $current_dir -- {*}$patterns];

        foreach fileToAdd $current_hdlfile {  #循环列表时列表名字不要忘记$
          lappend HDL_filelist $fileToAdd;  
        }
        set subdirectory [glob -nocomplain -types d -directory  $current_dir -- *];
        foreach SubdirCurrent $subdirectory {
        set HDLinCurrentSubdir  [recursivefind $SubdirCurrent];       
        foreach file2 $HDLinCurrentSubdir {
          lappend HDL_filelist $file2
        }

        }
       return  $HDL_filelist;
    }


    set hdllist [find_HDLfiles [pwd]];
foreach f $hdllist {
      set f [string map {\n \\n \r \\r} $f]
      puts $fileToWrite $f
    };

close $fileToWrite;


