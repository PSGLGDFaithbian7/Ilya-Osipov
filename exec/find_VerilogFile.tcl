#!/usr/bin/env tclsh

set outputfile "./list/rtl_design.list";
set fileToWrite [open $outputfile w];

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
        set current_hdlfile [glob -nocomplain -types f -directory $current_dir -- *.v *.sv *.vhdl *.vh *.svh *.vhd];

        foreach fileToAdd $current_hdlfile {  #循环列表时列表名字不要忘记$
          lappend HDL_filelist $fileToAdd;  
        }
        set subdirectory [glob -nocomplain -types d -directory  $current_dir -- *];
        foreach SubdirCurrent $subdirectory {
         set HDLinCurrentSubdir  [recursivefind $SubdirCurrent];
         set  HDL_filelist [concat $HDL_filelist  $HDLinCurrentSubdir];
        }
       return  $HDL_filelist;
    }


    set hdllist [find_HDLfiles [pwd]];
    foreach f $hdllist {
      puts $fileToWrite $f
    };

close $fileToWrite;