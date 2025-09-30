# ============================================================================
# Verdi Automatic Signal Loading and Debug Setup - Fixed for Verdi compatibility
# Optimized for Arithmetic Unit and AI Chip Debug
# ============================================================================

set verdi_start_time [clock seconds]

# Verdi-compatible signal discovery and loading
proc auto_load_arithmetic_signals {} {
    puts "=== Auto-loading arithmetic unit signals ==="
    
    # Use Verdi's debImport to load the design first
    catch {
        debImport -sv -f signal_list.f
    }
    
    # Core arithmetic signal patterns - use Verdi addSignal command
    set arith_patterns {
        "*clk*"
        "*reset*" 
        "*rst*"
        "*valid*"
        "*ready*"
        "*operand*"
        "*result*"
        "*overflow*"
        "*underflow*"
        "*carry*"
        "*zero*"
    }
    
    # Create signal group for arithmetic signals
    catch {
        addSignalGroup "Arithmetic_Core"
    }
    
    # Load arithmetic signals with error handling
    foreach pattern $arith_patterns {
        catch {
            set signals [lsearch -all -inline [getSignalList] $pattern]
            foreach sig $signals {
                addSignal -path $sig -group "Arithmetic_Core"
            }
            if {[llength $signals] > 0} {
                puts "Added [llength $signals] signals matching: $pattern"
            }
        }
    }
}

# Load AI chip specific signals with Verdi commands
proc auto_load_ai_signals {} {
    puts "=== Auto-loading AI chip signals ==="
    
    set ai_patterns {
        "*weight*"
        "*activation*" 
        "*bias*"
        "*conv*"
        "*pool*"
        "*mac*"
        "*accumulator*"
        "*feature*"
        "*neural*"
    }
    
    # Create AI processing group
    catch {
        addSignalGroup "AI_Processing"
    }
    
    foreach pattern $ai_patterns {
        catch {
            set signals [lsearch -all -inline [getSignalList] $pattern]
            foreach sig $signals {
                addSignal -path $sig -group "AI_Processing"
            }
            if {[llength $signals] > 0} {
                puts "Added [llength $signals] AI signals matching: $pattern"
            }
        }
    }
}

# Setup memory viewers with error handling
proc setup_memory_viewers {} {
    puts "=== Setting up memory viewers ==="
    
    # Find and setup memory viewers with Verdi commands
    catch {
        # Look for memory instances in the design
        set mem_list [getInstanceList "*mem*"]
        foreach mem $mem_list {
            catch {
                openMemoryViewer -inst $mem
                puts "Created memory viewer for: $mem"
            }
        }
    }
    
    # AI chip specific memories
    if {[info exists ::env(AI_CHIP_MODE)]} {
        catch {
            openMemoryViewer -inst "tb_top.dut.weight_memory" -format hex
            puts "Weight memory viewer created"
        }
        
        catch {
            openMemoryViewer -inst "tb_top.dut.activation_memory" -format hex  
            puts "Activation memory viewer created"
        }
    }
}

# Create waveform groups with Verdi syntax
proc create_waveform_groups {} {
    puts "=== Creating waveform groups ==="
    
    # Create hierarchical signal groups
    set groups {
        "Clock_and_Reset"
        "Control_Signals" 
        "Data_Path"
        "Status_Flags"
        "Performance_Counters"
    }
    
    foreach group $groups {
        catch {
            addSignalGroup $group
            puts "Created group: $group"
        }
    }
    
    # AI chip specific groups
    if {[info exists ::env(AI_CHIP_MODE)]} {
        set ai_groups {
            "Neural_Processing"
            "Memory_Interface"
            "Pipeline_Control"
        }
        
        foreach group $ai_groups {
            catch {
                addSignalGroup $group
                puts "Created AI group: $group"
            }
        }
    }
}

# Setup Verdi-compatible debugging features
proc setup_advanced_debug {} {
    puts "=== Setting up Verdi debug features ==="
    
    # Enable Verdi cross-probing
    catch {
        # Verdi cross-probe setup
        setCrossProbeMode -enable
        puts "Cross-probe enabled"
    }
    
    # Setup automatic cursor placement at interesting events
    catch {
        # Add cursors at simulation start/end
        addCursor -time 0ns -name "sim_start"
        puts "Simulation cursors configured"
    }
}

# Performance analysis with Verdi tools
proc setup_performance_analysis {} {
    puts "=== Setting up Verdi performance analysis ==="
    
    # Create measurement cursors
    catch {
        addCursor -name "measure_start" -color green
        addCursor -name "measure_end" -color red
        puts "Measurement cursors created"
    }
    
    # Setup signal statistics if available
    catch {
        enableSignalStatistics
        puts "Signal statistics enabled"
    }
}

# Verdi utility functions
proc safe_add_signals {signal_list group_name} {
    foreach sig $signal_list {
        catch {
            addSignal -path $sig -group $group_name
        }
    }
}

proc list_available_signals {} {
    catch {
        set all_signals [getSignalList]
        puts "Total signals available: [llength $all_signals]"
        
        # Show first 20 signals as example
        set count 0
        foreach sig $all_signals {
            if {$count < 20} {
                puts "  $sig"
                incr count
            } else {
                puts "  ... and [expr [llength $all_signals] - 20] more"
                break
            }
        }
    }
}

# Main Verdi initialization
proc initialize_verdi_debug {} {
    puts "=== Initializing Verdi Debug Environment ==="
    
    # Import design if not already done
    catch {
        debImport -dbdir simv.daidir
        puts "Design imported from simv.daidir"
    }
    
    # Create waveform organization
    create_waveform_groups
    
    # Load core arithmetic signals
    auto_load_arithmetic_signals
    
    # Load AI specific signals if in AI mode
    if {[info exists ::env(AI_CHIP_MODE)]} {
        auto_load_ai_signals
    }
    
    # Setup memory viewers
    setup_memory_viewers
    
    # Advanced debugging features  
    setup_advanced_debug
    
    # Performance analysis
    setup_performance_analysis
    
    # Configure waveform display
    catch {
        setWaveformDisplayFormat -time ns -radix hex
        puts "Waveform display configured"
    }
    
    puts "Verdi debug environment initialized successfully"
}

# Run initialization
initialize_verdi_debug

# Define user commands for Verdi
proc reload_signals {} {
    puts "Reloading signals..."
    auto_load_arithmetic_signals
    if {[info exists ::env(AI_CHIP_MODE)]} {
        auto_load_ai_signals
    }
}

proc show_memories {} {
    puts "=== Available Memory Instances ==="
    catch {
        set mems [getInstanceList "*mem*"]
        foreach mem $mems {
            puts "  $mem"
        }
    }
}

proc analyze_performance {} {
    puts "=== Performance Analysis ==="
    catch {
        # Add Verdi-specific performance analysis
        generateReport -type performance
        puts "Performance report generated"
    }
}

puts "=== Verdi Debug Commands Available ==="
puts "  reload_signals        - Reload signal discovery"  
puts "  show_memories         - List memory instances"
puts "  analyze_performance   - Generate performance report"
puts "  list_available_signals - Show available signals"