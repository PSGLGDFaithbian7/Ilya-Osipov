#!/usr/bin/env tclsh
# Simple YAML parser for configuration

namespace eval ::config {
    variable data {}
    
    proc load {config_file} {
        variable data
        
        if {![file exists $config_file]} {
            error "Configuration file not found: $config_file"
        }
        
        set fh [open $config_file r]
        set yaml_content [read $fh]
        close $fh
        
        set data [parse_yaml $yaml_content]
        return $data
    }
    
    proc parse_yaml {content} {
        set result [dict create]
        set current_path {}
        set indent_stack {0}
        set path_stack {{}}
        
        foreach line [split $content "\n"] {
            # Skip comments and empty lines
            if {[regexp {^\s*#|^\s*$} $line]} continue
            
            # Get indentation
            regexp {^(\s*)} $line indent
            set indent_level [string length $indent]
            
            # Handle list items
            if {[regexp {^(\s*)- (.+)$} $line _ spaces item]} {
                set item [string trim $item "\"'"]
                set full_path [concat {*}$path_stack]
                dict lappend result {*}$full_path $item
                continue
            }
            
            # Parse key-value pairs
            if {[regexp {^(\s*)([^:]+):\s*(.*)$} $line _ spaces key value]} {
                set key [string trim $key]
                set value [string trim $value "\"'"]
                
                # Adjust path based on indentation
                while {[lindex $indent_stack end] >= $indent_level && [llength $indent_stack] > 1} {
                    set indent_stack [lrange $indent_stack 0 end-1]
                    set path_stack [lrange $path_stack 0 end-1]
                }
                
                if {$value eq ""} {
                    # New section
                    lappend path_stack $key
                    lappend indent_stack $indent_level
                } else {
                    # Key-value pair
                    set full_path [concat {*}$path_stack $key]
                    dict set result {*}$full_path $value
                }
            }
        }
        
        return $result
    }
    
    proc get {path {default ""}} {
        variable data
        
        if {[dict exists $data {*}$path]} {
            return [dict get $data {*}$path]
        } else {
            return $default
        }
    }
}