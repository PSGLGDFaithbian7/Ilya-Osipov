#!/usr/bin/env tclsh

set fileToRead [open ./setup/library.lst r];
set fileToWrite [open ./work/script.tcl a];

puts $fileToWrite 


while {[gets $fileToRead line] >= 0} {
    
   if {[regexp {LibraryPath:/s(/S+)} $line match LibraryPath]} {   #选用/S+避免捕获空格
      puts $fileToWrite "set_app_var  search_path $LibraryPath"
      puts "--------------Library PATH--------------"
	  puts "$LibraryPath"
   };

   if {[regexp {LibraryFile:/s(/S+)} $line match LibraryFile]} {
      puts $fileToWrite "set_app_var target_library  /"*$LibraryFile/""
      puts $fileToWrite "set_app_var link_library  /"* $LibraryFile/""
      puts "--------------LIBRARY_NAME--------------"
      puts "$LibraryFile"
   };
    
    if {[regexp {TopModule:/s(/S+)} $line match TopModule]} {
      puts $fileToWrite "set TopModule $TopModule"
      puts "--------------TOP_NAME--------------"
      puts "$TopModule"
     
   };
    

};

close $fileToWrite;