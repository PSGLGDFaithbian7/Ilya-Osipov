#!/usr/bin/env tclsh

set fileToRead [open ./setup/library.lst r];
set fileToWrite [open ./work/script.tcl a];

puts $fileToWrite 


while {[gets $fileToRead line] >= 0} {
    
   if {[regexp {LibraryPath:/s(/S+)} $line match LibraryPath]} {   #选用/S+避免捕获空格
      puts "  $LibraryFile"
   };

   if {[regexp {LibraryFile:/s(/S+)} $line match LibraryFile]} {
    
   };
    
}