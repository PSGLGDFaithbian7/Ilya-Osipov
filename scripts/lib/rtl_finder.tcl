#!/usr/bin/env tclsh
# =============================================================================
# RTL File Finder - Original Recursive Search Preserved
# =============================================================================

namespace eval ::rtl {
    
    # Find all RTL files - ORIGINAL RECURSIVE LOGIC
    proc find_all_files {search_dirs patterns} {
        set all_files {}
        
        foreach dir $search_dirs {
            set dir [::utils::expand_vars $dir]
            if {[file isdirectory $dir]} {
                set dir [file normalize $dir]
                set files [recursive_find $dir $patterns]
                set all_files [concat $all_files $files]
            } else {
                puts "WARN: Directory not found: $dir"
            }
        }
        
        # Remove duplicates and sort
        return [lsort -unique $all_files]
    }
    
    # Recursive find - ORIGINAL LOGIC
    proc recursive_find {current_dir patterns} {
        set hdl_files {}
        
        # Find matching files in current directory
        foreach pattern $patterns {
            set files [glob -nocomplain -types f -directory $current_dir $pattern]
            foreach file $files {
                lappend hdl_files [file normalize $file]
            }
        }
        
        # Search subdirectories recursively
        set subdirs [glob -nocomplain -types d -directory $current_dir *]
        foreach subdir $subdirs {
            # Skip certain directories
            set dirname [file tail $subdir]
            if {$dirname in {.git .svn work output report log}} {
                continue
            }
            
            # Recursive call
            set sub_files [recursive_find $subdir $patterns]
            set hdl_files [concat $hdl_files $sub_files]
        }
        
        return $hdl_files
    }
}

# Generate RTL list script
if {[info exists argv0] && [file tail $argv0] eq "generate_rtl_list.tcl"} {
    # Load config
    source [file join [file dirname [info script]] config_parser.tcl]
    source [file join [file dirname [info script]] utils.tcl]
    
    if {[info exists ::env(CONFIG_FILE)]} {
        set config_file $::env(CONFIG_FILE)
    } else {
        set config_file "config/project_config.yaml"
    }
    
    set config [config::load $config_file]
    
    # Get RTL directories and patterns
    set rtl_dirs [dict get $config rtl search_dirs]
    set patterns [dict get $config rtl file_extensions]
    
    # Find all files
    set files [rtl::find_all_files $rtl_dirs $patterns]
    
    # Write to file
    set output_file "work/rtl_files.lst"
    file mkdir work
    set fh [open $output_file w]
    
    puts $fh "# RTL File List - Generated [clock format [clock seconds]]"
    puts $fh "# Total files: [llength $files]"
    puts $fh ""
    
    foreach file $files {
        puts $fh $file
    }
    
    close $fh
    
    puts "Generated RTL file list: $output_file"
    puts "Total RTL files found: [llength $files]"
}