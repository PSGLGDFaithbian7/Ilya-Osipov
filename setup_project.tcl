#!/usr/bin/env sg_shell
# Setup Project Script - P-2019 Compatible Version

# Source common procedures
set script_dir [file dirname [info script]]
source [file join $script_dir "common_procs.tcl"]

##############################################################################
# Configuration from Environment
##############################################################################

proc load_config_from_env {} {
    global PROJECT_NAME TOP_MODULES RTL_FILELIST INCLUDE_FILELIST
    global SG_WAIVER_FILE REUSE_MODE DEBUG_MODE BUILD_TAG
    
    set PROJECT_NAME     [get_env_var "PROJECT_NAME" "rtl_project"]
    set top_modules_str  [get_env_var "TOP_MODULES" "top_module"]
    set TOP_MODULES      [split $top_modules_str]
    set RTL_FILELIST     [get_env_var "RTL_FILELIST" "./config/rtl_files.f"]
    set INCLUDE_FILELIST [get_env_var "INCLUDE_FILELIST" "./config/include_files.f"]
    set SG_WAIVER_FILE   [get_env_var "SG_WAIVER_FILE" "./config/waivers.awl"]
    set REUSE_MODE       [get_env_var "REUSE" "0"]
    set DEBUG_MODE       [get_env_var "DEBUG" "0"]
    set BUILD_TAG        [get_env_var "BUILD_TAG" "unknown"]
    
    log_msg "INFO" "Configuration loaded:"
    log_msg "INFO" "  Project: $PROJECT_NAME"
    log_msg "INFO" "  Top Modules: $TOP_MODULES"
    log_msg "INFO" "  Build Tag: $BUILD_TAG"
    log_msg "INFO" "  Reuse: $REUSE_MODE"
    
    return 0
}

##############################################################################
# Project Setup
##############################################################################

proc setup_spyglass_project {} {
    global PROJECT_NAME TOP_MODULES RTL_FILELIST INCLUDE_FILELIST
    global SG_WAIVER_FILE REUSE_MODE DEBUG_MODE
    
    log_msg "INFO" "Setting up Spyglass project: $PROJECT_NAME"
    
    # Handle project creation/reuse
    if {$REUSE_MODE && [file exists "${PROJECT_NAME}.prj"]} {
        log_msg "INFO" "Reusing existing project"
        if {[catch {open_project ${PROJECT_NAME}.prj} err]} {
            log_msg "ERROR" "Failed to open project: $err"
            return -1
        }
    } else {
        log_msg "INFO" "Creating new project"
        if {[catch {new_project $PROJECT_NAME -force} err]} {
            log_msg "ERROR" "Failed to create project: $err"
            return -1
        }
    }
    
    # Read design files
    if {![validate_file $RTL_FILELIST "RTL filelist"]} {
        return -1
    }
    
    log_msg "INFO" "Reading RTL files from: $RTL_FILELIST"
    if {[catch {read_file -type sourcelist $RTL_FILELIST} err]} {
        log_msg "ERROR" "Failed to read RTL files: $err"
        return -1
    }
    
    # Apply include configuration
    if {[file exists $INCLUDE_FILELIST]} {
        log_msg "INFO" "Applying include configuration"
        apply_include_config $INCLUDE_FILELIST
    }
    
    # Apply waivers (optional)
    apply_waivers $SG_WAIVER_FILE
    
    # Configure for each top module
    foreach top $TOP_MODULES {
        log_msg "INFO" "Configuring for top module: $top"
        set_option top $top
        configure_analysis_options $top
    }
    
    log_msg "INFO" "Project setup completed successfully"
    return 0
}

##############################################################################
# Helper Functions
##############################################################################

proc apply_include_config {config_file} {
    set fp [open $config_file r]
    while {[gets $fp line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line]} {
            continue
        }
        
        if {[string match "+incdir+*" $line]} {
            set incdir [string range $line 8 end]
            if {[file isdirectory $incdir]} {
                if {[catch {set_option incdir $incdir} err]} {
                    log_msg "WARNING" "Failed to set incdir $incdir: $err"
                } else {
                    log_msg "INFO" "Added include directory: $incdir"
                }
            }
        } elseif {[string match "+include+*" $line]} {
            set incfile [string range $line 9 end]
            if {[file exists $incfile]} {
                if {[catch {read_file -type verilog $incfile} err]} {
                    log_msg "WARNING" "Failed to include file $incfile: $err"
                } else {
                    log_msg "INFO" "Included file: $incfile"
                }
            }
        }
    }
    close $fp
}

proc configure_analysis_options {top_module} {
    global DEBUG_MODE
    
    log_msg "INFO" "Configuring analysis options for: $top_module (P-2019 compatible)"
    
    # ===== 基础配置（P-2019兼容）=====
    if {[catch {set_option enableSV yes} err]} {
        log_msg "WARNING" "enableSV option not supported: $err"
    }
    
    if {[catch {set_option language_mode mixed} err]} {
        log_msg "WARNING" "language_mode option not supported: $err"
    }
    
    # ===== 以下选项在P-2019的sg_shell中不支持，仅GUI支持 =====
    # set_option designread_enable_synthesis yes  # ← 注释掉
    # set_option enable_gated_clock_conversion yes  # ← 可能不支持
    # set_option enable_clock_domain_analysis yes  # ← 可能不支持
    
    # ===== 时钟/复位检测（使用catch容错）=====
    if {[catch {set_option auto_detect_clock_reset yes} err]} {
        log_msg "INFO" "auto_detect_clock_reset not available (using defaults)"
    }
    
    if {[catch {set_option handle_default_clocking_block yes} err]} {
        log_msg "INFO" "handle_default_clocking_block not available"
    }
    
    # ===== 调试选项 =====
    if {$DEBUG_MODE} {
        if {[catch {set_option verbose yes} err]} {
            log_msg "WARNING" "verbose option not supported: $err"
        } else {
            log_msg "DEBUG" "Debug mode enabled"
        }
    }
    
    # ===== Lint检查配置（保守模式）=====
    if {[catch {set_option check_FSM yes} err]} {
        log_msg "INFO" "check_FSM not available"
    }
    
    log_msg "INFO" "Analysis options configured"
}

##############################################################################
# Main Execution (for standalone testing)
##############################################################################

if {[info script] eq $argv0} {
    load_config_from_env
    
    if {[setup_spyglass_project] == 0} {
        if {[catch {save_project} err]} {
            log_msg "ERROR" "Failed to save project: $err"
            exit 1
        }
        log_msg "INFO" "Project saved successfully"
        exit 0
    } else {
        log_msg "ERROR" "Project setup failed"
        exit 1
    }
}
