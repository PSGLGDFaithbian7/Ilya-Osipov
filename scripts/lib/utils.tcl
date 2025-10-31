#!/usr/bin/env tclsh
# Utility functions

namespace eval ::utils {
    proc print_section {title} {
        puts "\n========================================"
        puts " $title"
        puts "========================================"
    }
    
    proc print_banner {message} {
        set width 60
        set padding [expr {($width - [string length $message]) / 2}]
        puts "\n[string repeat "=" $width]"
        puts "[string repeat " " $padding]$message"
        puts "[string repeat "=" $width]\n"
    }
    
    proc expand_vars {str} {
        set result $str
        
        # Replace environment variables
        while {[regexp {\$\{([^}]+)\}} $result match var]} {
            if {[info exists ::env($var)]} {
                set value $::env($var)
            } else {
                set value ""
            }
            regsub {\$\{[^}]+\}} $result $value result
        }
        
        # Special case for PROJECT_ROOT
        regsub -all {\$\{PROJECT_ROOT\}} $result $::env(PROJECT_ROOT) result
        
        return $result
    }
}