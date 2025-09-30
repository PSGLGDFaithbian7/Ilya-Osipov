# ============================================================================
# Simulation Report Generator - Called after simulation completion
# ============================================================================

puts "=== Post-Simulation Report ==="

# Check for log files and extract statistics
if {[file exists "sim.log"]} {
    set fp [open "sim.log" r]
    set content [read $fp]
    close $fp
    
    # Extract VCS statistics
    if {[regexp {Simulation complete via \$finish\(1\) at time (\S+)} $content match sim_time]} {
        puts "Simulation completed at: $sim_time"
    }
    
    if {[regexp {CPU time: (\S+) seconds} $content match cpu_time]} {
        puts "CPU Time: $cpu_time seconds"
    }
}

# Check for FSDB files
set fsdb_files [glob -nocomplain *.fsdb]
if {[llength $fsdb_files] > 0} {
    puts "Waveform files generated:"
    foreach fsdb $fsdb_files {
        puts "  $fsdb ([file size $fsdb] bytes)"
    }
}

puts "=== Report Complete ==="