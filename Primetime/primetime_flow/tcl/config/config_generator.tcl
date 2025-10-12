#!/usr/bin/env pt_shell -f
#==============================================================================
# Configuration Generator
#==============================================================================

proc generate_config {output_file config_list} {
    set fp [open $output_file "w"]
    
    puts $fp "#==============================================================================
# Run Configuration
# Generated: [clock format [clock seconds]]
#==============================================================================

# Configuration array
array set ::CONFIG {}"
    
    foreach {key value} $config_list {
        puts $fp "set ::CONFIG($key) {$value}"
    }
    
    puts $fp "

# Print configuration
proc print_config {} {
    puts \"\\nConfiguration:\"
    foreach {key val} ```math
array get ::CONFIG``` {
        puts \"  \$key = \$val\"
    }
}
"
    
    close $fp
    puts "Configuration saved to: $output_file"
}

# Allow command-line execution
if {[info exists argv]} {
    eval $argv
}

exit 0