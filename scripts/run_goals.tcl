#!/usr/bin/env sg_shell
# Spyglass Goals - Production Version (No Directory Switching)
# Version: 5.1 - Full Featured, Simplified Paths
# All features retained, complexity removed

set script_dir [file dirname [info script]]
source [file join $script_dir "common_procs.tcl"]

##############################################################################
# Configuration (No Directory Switching)
##############################################################################

proc load_goal_config {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG REPORT_ONLY
    
    # All paths relative to current directory - no switching needed
    set RESULTS_DIR [get_env_var "RESULTS_DIR" "./results"]
    set TIMESTAMP   [get_env_var "TIMESTAMP" [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]]
    set top_str     [get_env_var "TOP_MODULES" "top_module"]
    set TOP_MODULES [split $top_str]
    set BUILD_TAG   [get_env_var "BUILD_TAG" "unknown"]
    set REPORT_ONLY [get_env_var "REPORT_ONLY" "0"]
    
    log_msg "INFO" "Goal configuration loaded"
    log_msg "INFO" "  Results Dir:  $RESULTS_DIR"
    log_msg "INFO" "  Timestamp:    $TIMESTAMP"
    log_msg "INFO" "  Top Modules:  $TOP_MODULES"
    log_msg "INFO" "  Build Tag:    $BUILD_TAG"
}

##############################################################################
# Report Collection Engine (No Directory Switching)
##############################################################################

proc collect_spyglass_reports {report_dir top_module goal_type} {
    log_msg "INFO" "========================================"
    log_msg "INFO" "Collecting $goal_type reports"
    log_msg "INFO" "  Module: $top_module"
    log_msg "INFO" "  Target: $report_dir"
    log_msg "INFO" "========================================"
    
    # Determine goal subdirectory based on type
    if {[string match "*lint*" $goal_type]} {
        set goal_subdir "lint/lint_rtl"
    } elseif {[string match "*cdc*" $goal_type]} {
        set goal_subdir "cdc/cdc_setup_check"
    } elseif {[string match "*rdc*" $goal_type]} {
        set goal_subdir "rdc/rdc_setup_check"
    } else {
        set goal_subdir "lint/lint_rtl"
    }
    
    # Spyglass creates reports in ./rtl_project/ (current directory)
    # No need for complex path resolution - just use relative paths
    set sg_module_dir "./rtl_project/$top_module"
    set sg_goal_dir "$sg_module_dir/$goal_subdir"
    set sg_reports_dir "$sg_goal_dir/spyglass_reports"
    
    set reports_collected 0
    set total_size 0
    
    log_msg "INFO" "Searching for reports in:"
    log_msg "INFO" "  $sg_goal_dir"
    
    # 1. Collect main log file
    set sg_log "$sg_goal_dir/spyglass.log"
    if {[file exists $sg_log]} {
        if {[catch {
            file copy -force $sg_log [file join $report_dir "spyglass_full.log"]
            set size [file size $sg_log]
            set total_size [expr {$total_size + $size}]
            log_msg "INFO" "  ✓ spyglass.log ([format_file_size $size])"
            incr reports_collected
        } err]} {
            log_msg "WARNING" "Failed to copy log: $err"
        }
    } else {
        log_msg "WARNING" "Log not found: $sg_log"
    }
    
    # 2. Collect all .rpt files from spyglass_reports
    if {[file exists $sg_reports_dir] && [file isdirectory $sg_reports_dir]} {
        set rpt_files [glob -nocomplain [file join $sg_reports_dir "*.rpt"]]
        log_msg "INFO" "Found [llength $rpt_files] report files"
        
        foreach rpt $rpt_files {
            if {[catch {
                set dest [file join $report_dir [file tail $rpt]]
                file copy -force $rpt $dest
                set size [file size $rpt]
                set total_size [expr {$total_size + $size}]
                log_msg "INFO" "  ✓ [file tail $rpt] ([format_file_size $size])"
                incr reports_collected
            } err]} {
                log_msg "WARNING" "Failed to copy [file tail $rpt]: $err"
            }
        }
        
        # 3. Collect subdirectories (lint/, cdc/, etc.)
        set subdirs [glob -nocomplain -type d [file join $sg_reports_dir "*"]]
        foreach subdir $subdirs {
            set dirname [file tail $subdir]
            set dest_subdir [file join $report_dir $dirname]
            
            if {[catch {
                file copy -force $subdir $dest_subdir
                set subdir_files [glob -nocomplain [file join $subdir "*"]]
                log_msg "INFO" "  ✓ $dirname/ ([llength $subdir_files] files)"
                incr reports_collected
            } err]} {
                log_msg "WARNING" "Failed to copy $dirname/: $err"
            }
        }
    } else {
        log_msg "WARNING" "Reports directory not found: $sg_reports_dir"
    }
    
    # 4. Collect consolidated reports if available
    set goal_name [string map {/ _} $goal_type]
    set sg_consolidated "./rtl_project/consolidated_reports/${top_module}_${goal_name}"
    
    if {[file exists $sg_consolidated] && [file isdirectory $sg_consolidated]} {
        log_msg "INFO" "Collecting consolidated reports..."
        set cons_dir [file join $report_dir "consolidated"]
        
        if {[catch {
            file mkdir $cons_dir
            set cons_files [glob -nocomplain [file join $sg_consolidated "*"]]
            foreach f $cons_files {
                if {[file isfile $f]} {
                    file copy -force $f $cons_dir
                    incr reports_collected
                }
            }
            log_msg "INFO" "  ✓ consolidated/ ([llength $cons_files] files)"
        } err]} {
            log_msg "WARNING" "Failed to collect consolidated: $err"
        }
    }
    
    # 5. Generate text index
    generate_report_index $report_dir $top_module $goal_type $reports_collected $total_size
    
    # 6. Generate HTML index for this module
    generate_module_html $report_dir $top_module $goal_type
    
    log_msg "INFO" "========================================"
    log_msg "INFO" "Collection Summary:"
    log_msg "INFO" "  Reports: $reports_collected"
    log_msg "INFO" "  Size:    [format_file_size $total_size]"
    log_msg "INFO" "========================================"
    
    return $reports_collected
}

##############################################################################
# Report Index Generation (Text)
##############################################################################

proc generate_report_index {report_dir top_module goal_type count total_size} {
    set index_file [file join $report_dir "00_README.txt"]
    
    if {[catch {
        set fp [open $index_file w]
        
        puts $fp "================================================================="
        puts $fp " Spyglass $goal_type Analysis Report"
        puts $fp "================================================================="
        puts $fp ""
        puts $fp "Module:           $top_module"
        puts $fp "Analysis Type:    $goal_type"
        puts $fp "Generated:        [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]"
        puts $fp "Reports Count:    $count"
        puts $fp "Total Size:       [format_file_size $total_size]"
        puts $fp ""
        puts $fp "Location:         [file normalize $report_dir]"
        puts $fp ""
        puts $fp "================================================================="
        puts $fp " Files in This Directory"
        puts $fp "================================================================="
        puts $fp ""
        
        # List all files and directories
        set all_items [glob -nocomplain [file join $report_dir "*"]]
        
        # Separate files and directories
        set files [list]
        set dirs [list]
        foreach item [lsort $all_items] {
            if {[file isfile $item]} {
                lappend files $item
            } elseif {[file isdirectory $item]} {
                lappend dirs $item
            }
        }
        
        # List files
        if {[llength $files] > 0} {
            puts $fp "Files:"
            foreach f $files {
                set name [file tail $f]
                set size [file size $f]
                puts $fp [format "  %-45s %12s" $name [format_file_size $size]]
            }
            puts $fp ""
        }
        
        # List directories
        if {[llength $dirs] > 0} {
            puts $fp "Directories:"
            foreach d $dirs {
                set name [file tail $d]
                set file_count [llength [glob -nocomplain [file join $d "*"]]]
                puts $fp [format "  %-45s %d items" "$name/" $file_count]
            }
            puts $fp ""
        }
        
        puts $fp "================================================================="
        puts $fp " Key Reports"
        puts $fp "================================================================="
        puts $fp ""
        puts $fp "  spyglass_full.log       Complete Spyglass execution log"
        puts $fp "  moresimple.rpt          Violation summary (simplified)"
        puts $fp "  index.html              HTML report viewer"
        puts $fp ""
        puts $fp "To view violations:"
        puts $fp "  cat moresimple.rpt"
        puts $fp ""
        puts $fp "To view in browser:"
        puts $fp "  firefox index.html"
        puts $fp ""
        puts $fp "================================================================="
        
        close $fp
        log_msg "INFO" "Generated text index: 00_README.txt"
    } err]} {
        log_msg "WARNING" "Failed to generate index: $err"
    }
}

##############################################################################
# HTML Report Generation (Module Level)
##############################################################################

proc generate_module_html {report_dir module_name goal_type} {
    set html_file [file join $report_dir "index.html"]
    
    if {[catch {
        set fp [open $html_file w]
        
        puts $fp "<!DOCTYPE html>"
        puts $fp "<html lang='en'>"
        puts $fp "<head>"
        puts $fp "    <meta charset='UTF-8'>"
        puts $fp "    <title>$module_name - $goal_type</title>"
        puts $fp "    <style>"
        puts $fp "        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }"
        puts $fp "        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }"
        puts $fp "        h1 { color: #667eea; border-bottom: 3px solid #667eea; padding-bottom: 10px; }"
        puts $fp "        .info { background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #667eea; }"
        puts $fp "        table { width: 100%; border-collapse: collapse; margin: 20px 0; }"
        puts $fp "        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }"
        puts $fp "        th { background: #667eea; color: white; }"
        puts $fp "        tr:hover { background: #f8f9fa; }"
        puts $fp "        a { color: #667eea; text-decoration: none; font-weight: 500; }"
        puts $fp "        a:hover { text-decoration: underline; }"
        puts $fp "        .badge { display: inline-block; padding: 4px 10px; border-radius: 12px; font-size: 0.85em; font-weight: 600; }"
        puts $fp "        .badge-log { background: #e3f2fd; color: #1976d2; }"
        puts $fp "        .badge-rpt { background: #f3e5f5; color: #7b1fa2; }"
        puts $fp "        .badge-dir { background: #fff3e0; color: #e65100; }"
        puts $fp "        .back-link { display: inline-block; margin-top: 20px; padding: 10px 20px; background: #667eea; color: white; border-radius: 5px; }"
        puts $fp "        .back-link:hover { background: #5568d3; text-decoration: none; }"
        puts $fp "    </style>"
        puts $fp "</head>"
        puts $fp "<body>"
        puts $fp "    <div class='container'>"
        puts $fp "        <h1>📊 $module_name</h1>"
        puts $fp "        <div class='info'>"
        puts $fp "            <strong>Analysis Type:</strong> $goal_type<br>"
        puts $fp "            <strong>Generated:</strong> [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]<br>"
        puts $fp "            <strong>Location:</strong> <code>[file normalize $report_dir]</code>"
        puts $fp "        </div>"
        
        puts $fp "        <h2>📑 Report Files</h2>"
        puts $fp "        <table>"
        puts $fp "            <thead>"
        puts $fp "                <tr><th>File Name</th><th>Type</th><th>Size</th></tr>"
        puts $fp "            </thead>"
        puts $fp "            <tbody>"
        
        # List all items
        set all_items [glob -nocomplain [file join $report_dir "*"]]
        foreach item [lsort $all_items] {
            set name [file tail $item]
            
            # Skip hidden files and this HTML itself
            if {[string match ".*" $name] || $name eq "index.html" || $name eq "00_README.txt"} {
                continue
            }
            
            if {[file isfile $item]} {
                set size [format_file_size [file size $item]]
                set type "Report"
                set badge_class "badge-rpt"
                
                if {[string match "*.log" $name]} {
                    set type "Log"
                    set badge_class "badge-log"
                }
                
                puts $fp "                <tr>"
                puts $fp "                    <td><a href='$name'>📄 $name</a></td>"
                puts $fp "                    <td><span class='badge $badge_class'>$type</span></td>"
                puts $fp "                    <td>$size</td>"
                puts $fp "                </tr>"
            } elseif {[file isdirectory $item]} {
                set count [llength [glob -nocomplain [file join $item "*"]]]
                
                puts $fp "                <tr>"
                puts $fp "                    <td><a href='$name/'>📁 $name/</a></td>"
                puts $fp "                    <td><span class='badge badge-dir'>Directory</span></td>"
                puts $fp "                    <td>$count items</td>"
                puts $fp "                </tr>"
            }
        }
        
        puts $fp "            </tbody>"
        puts $fp "        </table>"
        
        puts $fp "        <a href='../index.html' class='back-link'>← Back to Run Summary</a>"
        puts $fp "    </div>"
        puts $fp "</body>"
        puts $fp "</html>"
        
        close $fp
        log_msg "INFO" "Generated module HTML: index.html"
    } err]} {
        log_msg "WARNING" "Failed to generate module HTML: $err"
    }
}

##############################################################################
# Run Summary Generation
##############################################################################

proc generate_run_summary {run_dir analysis_type build_tag total failed} {
    # Generate text summary
    set summary_file [file join $run_dir "00_SUMMARY.txt"]
    
    if {[catch {
        set fp [open $summary_file w]
        
        puts $fp "================================================================="
        puts $fp " $analysis_type Analysis - Run Summary"
        puts $fp "================================================================="
        puts $fp ""
        puts $fp "Build Tag:         $build_tag"
        puts $fp "Timestamp:         [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]"
        puts $fp "Run Directory:     [file normalize $run_dir]"
        puts $fp ""
        puts $fp "Modules Total:     $total"
        puts $fp "Modules Success:   [expr {$total - $failed}]"
        puts $fp "Modules Failed:    $failed"
        puts $fp ""
        
        if {$failed > 0} {
            puts $fp "Status:            ⚠️  FAILED"
        } else {
            puts $fp "Status:            ✓  SUCCESS"
        }
        
        puts $fp ""
        puts $fp "================================================================="
        puts $fp " Module Reports"
        puts $fp "================================================================="
        puts $fp ""
        
        # List all module directories
        set module_dirs [glob -nocomplain -type d [file join $run_dir "*"]]
        set actual_modules [list]
        
        foreach mod_dir [lsort $module_dirs] {
            set mod_name [file tail $mod_dir]
            
            # Skip summary files
            if {[string match "00_*" $mod_name]} {
                continue
            }
            
            lappend actual_modules $mod_name
            
            puts $fp "Module: $mod_name"
            puts $fp "  Location:  $mod_dir"
            
            # Count reports
            set report_count [llength [glob -nocomplain [file join $mod_dir "*.rpt"]]]
            puts $fp "  Reports:   $report_count files"
            
            # Check for HTML
            if {[file exists [file join $mod_dir "index.html"]]} {
                puts $fp "  HTML:      index.html"
            }
            
            puts $fp ""
        }
        
        puts $fp "================================================================="
        puts $fp " Quick Start"
        puts $fp "================================================================="
        puts $fp ""
        puts $fp "View HTML report:"
        puts $fp "  firefox [file normalize $run_dir]/index.html"
        puts $fp ""
        puts $fp "View module reports:"
        puts $fp "  cd [file normalize $run_dir]/<module_name>"
        puts $fp "  cat 00_README.txt"
        puts $fp ""
        puts $fp "================================================================="
        
        close $fp
        log_msg "INFO" "Generated run summary: 00_SUMMARY.txt"
    } err]} {
        log_msg "WARNING" "Failed to generate summary: $err"
    }
    
    # Generate HTML index for the run
    generate_run_html $run_dir $analysis_type $build_tag $total $failed
}

##############################################################################
# HTML Report Generation (Run Level)
##############################################################################

proc generate_run_html {run_dir analysis_type build_tag total failed} {
    set html_file [file join $run_dir "index.html"]
    
    if {[catch {
        set fp [open $html_file w]
        
        puts $fp "<!DOCTYPE html>"
        puts $fp "<html lang='en'>"
        puts $fp "<head>"
        puts $fp "    <meta charset='UTF-8'>"
        puts $fp "    <meta name='viewport' content='width=device-width, initial-scale=1.0'>"
        puts $fp "    <title>$analysis_type Analysis Report</title>"
        puts $fp "    <style>"
        puts $fp "        * { margin: 0; padding: 0; box-sizing: border-box; }"
        puts $fp "        body { font-family: 'Segoe UI', sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; min-height: 100vh; }"
        puts $fp "        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 15px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); overflow: hidden; }"
        puts $fp "        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; }"
        puts $fp "        .header h1 { font-size: 2.5em; margin-bottom: 10px; }"
        puts $fp "        .status { display: inline-block; padding: 10px 30px; border-radius: 20px; font-size: 1.2em; margin-top: 10px; }"
        puts $fp "        .status-success { background: #4caf50; color: white; }"
        puts $fp "        .status-failed { background: #f44336; color: white; }"
        puts $fp "        .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; padding: 30px; background: #f8f9fa; }"
        puts $fp "        .info-card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }"
        puts $fp "        .info-card h3 { color: #667eea; font-size: 0.9em; text-transform: uppercase; margin-bottom: 8px; }"
        puts $fp "        .info-card p { font-size: 1.8em; color: #333; font-weight: bold; }"
        puts $fp "        .content { padding: 40px; }"
        puts $fp "        .section-title { font-size: 1.8em; color: #333; margin-bottom: 20px; padding-bottom: 10px; border-bottom: 3px solid #667eea; }"
        puts $fp "        .module-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; margin-top: 20px; }"
        puts $fp "        .module-card { background: white; border: 2px solid #e0e0e0; border-radius: 10px; padding: 20px; transition: all 0.3s; }"
        puts $fp "        .module-card:hover { border-color: #667eea; box-shadow: 0 5px 15px rgba(102,126,234,0.3); transform: translateY(-2px); }"
        puts $fp "        .module-card h3 { color: #667eea; margin-bottom: 15px; }"
        puts $fp "        .module-card a { display: inline-block; margin-top: 10px; padding: 8px 20px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; }"
        puts $fp "        .module-card a:hover { background: #5568d3; }"
        puts $fp "        .footer { padding: 20px; text-align: center; background: #f8f9fa; color: #666; border-top: 1px solid #e0e0e0; }"
        puts $fp "    </style>"
        puts $fp "</head>"
        puts $fp "<body>"
        puts $fp "    <div class='container'>"
        
        # Header
        puts $fp "        <div class='header'>"
        puts $fp "            <h1>📊 $analysis_type Analysis</h1>"
        
        if {$failed > 0} {
            puts $fp "            <div class='status status-failed'>⚠️ Failed ($failed/$total modules)</div>"
        } else {
            puts $fp "            <div class='status status-success'>✓ All Passed</div>"
        }
        
        puts $fp "        </div>"
        
        # Info Grid
        puts $fp "        <div class='info-grid'>"
        puts $fp "            <div class='info-card'><h3>📅 Generated</h3><p style='font-size:1.2em;'>[clock format [clock seconds] -format "%Y-%m-%d %H:%M"]</p></div>"
        puts $fp "            <div class='info-card'><h3>🏷️ Build Tag</h3><p style='font-size:1.0em;'>$build_tag</p></div>"
        puts $fp "            <div class='info-card'><h3>📦 Total Modules</h3><p>$total</p></div>"
        puts $fp "            <div class='info-card'><h3>✓ Success</h3><p style='color:#4caf50;'>[expr {$total - $failed}]</p></div>"
        
        if {$failed > 0} {
            puts $fp "            <div class='info-card'><h3>✗ Failed</h3><p style='color:#f44336;'>$failed</p></div>"
        }
        
        puts $fp "        </div>"
        
        # Module List
        puts $fp "        <div class='content'>"
        puts $fp "            <h2 class='section-title'>📂 Module Reports</h2>"
        puts $fp "            <div class='module-grid'>"
        
        # Find all module directories
        set module_dirs [glob -nocomplain -type d [file join $run_dir "*"]]
        
        foreach mod_dir [lsort $module_dirs] {
            set mod_name [file tail $mod_dir]
            
            # Skip summary files
            if {[string match "00_*" $mod_name]} {
                continue
            }
            
            set report_count [llength [glob -nocomplain [file join $mod_dir "*.rpt"]]]
            set has_html [file exists [file join $mod_dir "index.html"]]
            
            puts $fp "                <div class='module-card'>"
            puts $fp "                    <h3>$mod_name</h3>"
            puts $fp "                    <p style='color:#666; font-size:0.9em;'>$report_count report files</p>"
            
            if {$has_html} {
                puts $fp "                    <a href='$mod_name/index.html'>View Reports →</a>"
            } else {
                puts $fp "                    <a href='$mod_name/'>Browse Files →</a>"
            }
            
            puts $fp "                </div>"
        }
        
        puts $fp "            </div>"
        puts $fp "        </div>"
        
        # Footer
        puts $fp "        <div class='footer'>"
        puts $fp "            <p>Spyglass Analysis Framework v5.1 | Location: [file normalize $run_dir]</p>"
        puts $fp "        </div>"
        
        puts $fp "    </div>"
        puts $fp "</body>"
        puts $fp "</html>"
        
        close $fp
        log_msg "INFO" "Generated run HTML: index.html"
    } err]} {
        log_msg "ERROR" "Failed to generate run HTML: $err"
    }
}

##############################################################################
# Lint Goal (No Directory Switching)
##############################################################################

proc run_lint_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG REPORT_ONLY
    
    log_msg "INFO" "================================================================="
    log_msg "INFO" " LINT ANALYSIS"
    log_msg "INFO" "================================================================="
    
    set run_dir [ensure_dir [file join $RESULTS_DIR "lint" "run_$TIMESTAMP"]]
    set modules_failed 0
    
    foreach top $TOP_MODULES {
        log_msg "INFO" ""
        log_msg "INFO" "Processing module: $top"
        log_msg "INFO" "-----------------------------------------------------------------"
        
        start_timer "lint_$top"
        set module_failed 0
        
        if {!$REPORT_ONLY} {
            # Simple flow - all in current directory
            if {[catch {
                current_goal none
                set_option top $top
                current_goal lint/lint_rtl
                
                log_msg "INFO" "Compiling design..."
                compile_design
                
                log_msg "INFO" "Running lint analysis..."
                run_goal
                
                log_msg "INFO" "Saving project..."
                save_project
                
            } err]} {
                log_msg "ERROR" "Analysis failed for $top: $err"
                incr modules_failed
                set module_failed 1
            }
        }
        
        set elapsed [stop_timer "lint_$top"]
        
        # Collect reports
        if {!$module_failed} {
            set module_report_dir [ensure_dir [file join $run_dir $top]]
            set reports_count [collect_spyglass_reports $module_report_dir $top "lint/lint_rtl"]
            
            log_msg "INFO" "Module $top completed in [format "%.2f" [expr {$elapsed/1000.0}]]s"
            log_msg "INFO" "Collected $reports_count report files"
        }
    }
    
    # Generate run summary
    generate_run_summary $run_dir "Lint" $BUILD_TAG [llength $TOP_MODULES] $modules_failed
    
    log_msg "INFO" ""
    log_msg "INFO" "================================================================="
    log_msg "INFO" " LINT ANALYSIS COMPLETE"
    log_msg "INFO" "================================================================="
    log_msg "INFO" "Results:     [file normalize $run_dir]"
    log_msg "INFO" "HTML Report: file://[file normalize [file join $run_dir "index.html"]]"
    log_msg "INFO" "Status:      [expr {$modules_failed > 0 ? "FAILED" : "SUCCESS"}]"
    log_msg "INFO" "================================================================="
    
    return [expr {$modules_failed > 0 ? 1 : 0}]
}

##############################################################################
# CDC Goal (No Directory Switching)
##############################################################################

proc run_cdc_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG REPORT_ONLY
    
    log_msg "INFO" "================================================================="
    log_msg "INFO" " CDC ANALYSIS"
    log_msg "INFO" "================================================================="
    
    set run_dir [ensure_dir [file join $RESULTS_DIR "cdc" "run_$TIMESTAMP"]]
    set modules_failed 0
    
    foreach top $TOP_MODULES {
        log_msg "INFO" "CDC analysis for: $top"
        start_timer "cdc_$top"
        
        if {!$REPORT_ONLY} {
            if {[catch {
                current_goal none
                set_option top $top
                current_goal cdc/cdc_setup_check
                compile_design
                run_goal
                save_project
            } err]} {
                log_msg "ERROR" "CDC failed for $top: $err"
                incr modules_failed
            } else {
                set module_report_dir [ensure_dir [file join $run_dir $top]]
                collect_spyglass_reports $module_report_dir $top "cdc/cdc_setup_check"
            }
        }
        
        stop_timer "cdc_$top"
    }
    
    generate_run_summary $run_dir "CDC" $BUILD_TAG [llength $TOP_MODULES] $modules_failed
    
    log_msg "INFO" "CDC COMPLETE - Results: [file normalize $run_dir]"
    return [expr {$modules_failed > 0 ? 1 : 0}]
}

##############################################################################
# RDC Goal (No Directory Switching)
##############################################################################

proc run_rdc_goal {} {
    global RESULTS_DIR TIMESTAMP TOP_MODULES BUILD_TAG REPORT_ONLY
    
    log_msg "INFO" "================================================================="
    log_msg "INFO" " RDC ANALYSIS"
    log_msg "INFO" "================================================================="
    
    set run_dir [ensure_dir [file join $RESULTS_DIR "rdc" "run_$TIMESTAMP"]]
    set modules_failed 0
    
    foreach top $TOP_MODULES {
        log_msg "INFO" "RDC analysis for: $top"
        start_timer "rdc_$top"
        
        if {!$REPORT_ONLY} {
            if {[catch {
                current_goal none
                set_option top $top
                current_goal rdc/rdc_setup_check
                compile_design
                run_goal
                save_project
            } err]} {
                log_msg "ERROR" "RDC failed for $top: $err"
                incr modules_failed
            } else {
                set module_report_dir [ensure_dir [file join $run_dir $top]]
                collect_spyglass_reports $module_report_dir $top "rdc/rdc_setup_check"
            }
        }
        
        stop_timer "rdc_$top"
    }
    
    generate_run_summary $run_dir "RDC" $BUILD_TAG [llength $TOP_MODULES] $modules_failed
    
    log_msg "INFO" "RDC COMPLETE - Results: [file normalize $run_dir]"
    return [expr {$modules_failed > 0 ? 1 : 0}]
}

##############################################################################
# Utility Functions
##############################################################################

proc format_file_size {bytes} {
    if {$bytes < 1024} {
        return "${bytes} B"
    } elseif {$bytes < 1048576} {
        return "[format "%.1f" [expr {$bytes/1024.0}]] KB"
    } else {
        return "[format "%.1f" [expr {$bytes/1048576.0}]] MB"
    }
}

##############################################################################
# Initialize
##############################################################################

log_msg "INFO" "run_goals.tcl v5.1 loaded (Full Features, No Directory Switching)"
load_goal_config
