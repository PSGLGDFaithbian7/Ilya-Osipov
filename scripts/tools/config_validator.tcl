#!/usr/bin/env tclsh
# =============================================================================
# Configuration Validator - TCL Version
# =============================================================================

source [file join [file dirname [info script]] ../lib/config_parser.tcl]

proc validate_config {config_file} {
    set errors {}
    set warnings {}
    
    # Load configuration
    if {![file exists $config_file]} {
        puts "ERROR: Configuration file not found: $config_file"
        return 1
    }
    
    set config [config::load $config_file]
    
    # Check required fields
    set required_fields {
        {project top_module}
        {library target_libraries}
        {library link_libraries}
        {rtl search_dirs}
        {clocks}
    }
    
    foreach field $required_fields {
        if {[llength $field] == 1} {
            if {![dict exists $config {*}$field]} {
                lappend errors "Missing required field: $field"
            }
        } else {
            if {![dict exists $config {*}$field]} {
                lappend errors "Missing required field: [join $field .]"
            }
        }
    }
    
    # Validate clocks
    if {[dict exists $config clocks]} {
        set clocks [dict get $config clocks]
        set clock_names {}
        
        foreach clock $clocks {
            if {![dict exists $clock name]} {
                lappend errors "Clock missing 'name' field"
            } else {
                set name [dict get $clock name]
                if {$name in $clock_names} {
                    lappend errors "Duplicate clock name: $name"
                }
                lappend clock_names $name
            }
            
            if {![dict exists $clock period]} {
                lappend errors "Clock missing 'period' field"
            } else {
                set period [dict get $clock period]
                if {![string is double $period] || $period <= 0} {
                    lappend errors "Invalid clock period: $period"
                }
            }
        }
    }
    
    # Validate resets
    if {[dict exists $config resets]} {
        set resets [dict get $config resets]
        set reset_names {}
        
        foreach reset $resets {
            if {![dict exists $reset name]} {
                lappend errors "Reset missing 'name' field"
            } else {
                set name [dict get $reset name]
                if {$name in $reset_names} {
                    lappend errors "Duplicate reset name: $name"
                }
                lappend reset_names $name
            }
        }
    }
    
    # Check library files exist (warnings only)
    if {[dict exists $config library target_libraries]} {
        foreach lib [dict get $config library target_libraries] {
            if {![string match "*.db" $lib]} {
                lappend warnings "Library should have .db extension: $lib"
            }
        }
    }
    
    # Report results
    if {[llength $errors] > 0} {
        puts "Configuration Validation FAILED:"
        foreach error $errors {
            puts "  ERROR: $error"
        }
        return 1
    } else {
        puts "Configuration Validation PASSED"
        if {[llength $warnings] > 0} {
            foreach warning $warnings {
                puts "  WARNING: $warning"
            }
        }
        return 0
    }
}

# Main execution
if {[info exists argv0]} {
    if {[llength $argv] != 1} {
        puts "Usage: config_validator.tcl <config_file>"
        exit 1
    }
    
    exit [validate_config [lindex $argv 0]]
}