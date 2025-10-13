#!/usr/bin/env tclsh
# scripts/open_verdi.tcl
# Verdi Quick Launcher - TCL Version
# Usage: tclsh scripts/open_verdi.tcl [options]

# ============================================================================
# Configuration
# ============================================================================
set WORK_DIR "work"
set SCRIPT_DIR "scripts"
set PROJECT_NAME "arithmetic_unit"

# ============================================================================
# Parse Arguments
# ============================================================================
set auto_load 0
set debug_mode 0
set specific_file ""

foreach arg $argv {
    switch -glob -- $arg {
        "--auto" - "-a" {
            set auto_load 1
        }
        "--debug" - "-d" {
            set debug_mode 1
        }
        "--help" - "-h" {
            puts "Usage: tclsh scripts/open_verdi.tcl ```math
options```"
            puts ""
            puts "Options:"
            puts "  -a, --auto    Auto-load signals"
            puts "  -d, --debug   Include debug database"
            puts "  -h, --help    Show this help"
            puts ""
            puts "Examples:"
            puts "  tclsh scripts/open_verdi.tcl"
            puts "  tclsh scripts/open_verdi.tcl --auto"
            exit 0
        }
        default {
            if {[file exists $arg]} {
                set specific_file $arg
            }
        }
    }
}

# ============================================================================
# Find Latest FSDB
# ============================================================================
proc find_latest_fsdb {work_dir} {
    set fsdb_files [glob -nocomplain -directory $work_dir *.fsdb]
    
    if {[llength $fsdb_files] == 0} {
        return ""
    }
    
    # Sort by modification time (newest first)
    set sorted [lsort -command {
        lambda {a b} {
            expr {[file mtime $b] - [file mtime $a]}
        }
    } $fsdb_files]
    
    return [lindex $sorted 0]
}

# ============================================================================
# List Available FSDB Files
# ============================================================================
proc list_fsdb_files {work_dir} {
    set fsdb_files [glob -nocomplain -directory $work_dir *.fsdb]
    
    if {[llength $fsdb_files] == 0} {
        puts "No FSDB files found in $work_dir/"
        return 0
    }
    
    puts "\n=== Available FSDB Files ==="
    set count 1
    foreach fsdb $fsdb_files {
        set size [file size $fsdb]
        set size_mb [format "%.2f" [expr {$size / 1048576.0}]]
        set mtime [clock format [file mtime $fsdb] -format "%Y-%m-%d %H:%M:%S"]
        
        puts "  ```math
$count``` [file tail $fsdb]"
        puts "      Size: ${size_mb} MB, Modified: $mtime"
        incr count
    }
    puts ""
    
    return [llength $fsdb_files]
}

# ============================================================================
# Launch Verdi
# ============================================================================
proc launch_verdi {fsdb_file auto_load debug_mode script_dir} {
    puts "\n=== Launching Verdi ==="
    puts "FSDB: $fsdb_file"
    
    # Build command
    set cmd "verdi -ssf \"$fsdb_file\" -nologo"
    
    # Add signal auto-loading
    if {$auto_load} {
        set signal_script "$script_dir/signals.tcl"
        if {[file exists $signal_script]} {
            append cmd " -play \"$signal_script\""
            puts "Auto-loading signals: $signal_script"
        } else {
            puts "Warning: signals.tcl not found, skipping auto-load"
        }
    }
    
    # Add debug database
    if {$debug_mode} {
        if {[file exists "work/simv.daidir"]} {
            append cmd " -dbdir work/simv.daidir"
            puts "Debug database: work/simv.daidir"
        } else {
            puts "Warning: simv.daidir not found, skipping debug mode"
        }
    }
    
    # Launch in background
    append cmd " &"
    
    puts "Command: $cmd"
    puts ""
    
    # Execute
    if {[catch {exec sh -c $cmd} result]} {
        puts "Error launching Verdi: $result"
        return 1
    }
    
    puts "✓ Verdi launched successfully"
    return 0
}

# ============================================================================
# Main Execution
# ============================================================================

puts "=========================================="
puts "  Verdi Quick Launcher"
puts "=========================================="

# Check if work directory exists
if {![file exists $WORK_DIR]} {
    puts "Error: Work directory not found: $WORK_DIR"
    puts "Run 'make sim_waves' first to generate waveforms"
    exit 1
}

# Determine which FSDB to open
if {$specific_file ne ""} {
    if {![file exists $specific_file]} {
        puts "Error: Specified file not found: $specific_file"
        exit 1
    }
    set fsdb_file $specific_file
} else {
    # List available files
    set count [list_fsdb_files $WORK_DIR]
    
    if {$count == 0} {
        puts "No FSDB files found. Generate waveforms with:"
        puts "  make sim_waves"
        puts "  make sim_custom PLUSARGS=\"+DUMP_FSDB\""
        exit 1
    }
    
    # Get latest
    set fsdb_file [find_latest_fsdb $WORK_DIR]
    
    if {$fsdb_file eq ""} {
        puts "Error: Could not determine FSDB file"
        exit 1
    }
    
    puts "Using latest: [file tail $fsdb_file]"
}

# Launch Verdi
set result [launch_verdi $fsdb_file $auto_load $debug_mode $SCRIPT_DIR]

exit $result