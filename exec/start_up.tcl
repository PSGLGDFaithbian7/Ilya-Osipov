##########file#########
set DATE [exec date "+%Y%m%d_%H%M"]

##检查
if {![file exists ./work]}  { 
   file mkdir ./work };

if {![file exists ./setup]} { 
   error "missing ./setup directory" };
   
if {![file exists ./setup/library.lst]} { 
   error "missing ./setup/library.lst" };


##读入文件
set fileToRead [open ./setup/library.lst r];
set fileToWrite [open ./work/script.tcl a];



puts $fp_write "########Start########"
puts $fp_write "set_host_options -max_cores 16"
puts $fp_write "set_svf  ../output/${TOP_NAME}_${DATE}.svf"

close $fp_write
close $chan