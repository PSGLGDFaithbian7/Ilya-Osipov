
#!/usr/bin/env tclsh

#******time stamp****
set DATE [exec date "+%Y%m%d_%H%M"]

#********find all .v format file**********
source ./exec/find_VerilogFile.tcl

#********Set_up********
source ./exec/Set_Up.tcl

#********Read design******
source ./exec/read_design.tcl

#******set_clock*****
source ./exec/set_load.tcl

#******set_load*****
source ./exec/set_library.tcl

#*****set_reset
source ./exec/set_reset.tcl

#*****compile*****
source ./exec/compile.tcl

#******report output****
source ./exec/repo.tcl

