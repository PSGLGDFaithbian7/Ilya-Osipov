#==============================================================================
# Module: Initialization
# Description: Environment setup and initialization
#==============================================================================

namespace eval ::PT {
    variable initialized 0
}

proc ::PT::init_environment {} {
    variable initialized
    
    if {$initialized} {
        puts "Environment already initialized"
        return
    }
    
    puts "\n=== Initializing PrimeTime Environment ==="
    
    # Load configuration
    if {![info exists ::CONFIG]} {
        error "Configuration not loaded"
    }
    
    # Set PrimeTime variables
    set_app_var sh_enable_page_mode false
    set_app_var report_default_significant_digits 3
    
    # Enable power if needed
    set_app_var power_enable_analysis true
    
    # Set search paths
    set_app_var search_path $::CONFIG(SEARCH_PATH)
    set_app_var link_path $::CONFIG(LINK_LIBRARY)
    
    # Debug settings
    if {$::CONFIG(DEBUG)} {
        set_app_var sh_command_log_file "$::CONFIG(LOG_DIR)/commands.log"
    }
    
    set initialized 1
    puts "✓ Environment initialized"
}

proc ::PT::init_logging {} {
    set timestamp [clock format [clock seconds] -format "%H%M%S"]
    set log_file "$::CONFIG(LOG_DIR)/session_${timestamp}.log"
    
    set_app_var sh_output_log_file $log_file
    puts "✓ Session log: $log_file"
}

proc ::PT::print_header {title} {
    set width 60
    set padding [expr {($width - [string length $title]) / 2}]
    
    puts "\n[string repeat "=" $width]"
    puts "[string repeat " " $padding]$title"
    puts "[string repeat "=" $width]\n"
}