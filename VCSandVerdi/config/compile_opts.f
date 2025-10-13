# ============================================================================
# VCS Additional Compilation Options File
# ============================================================================
# This file contains extra compilation flags that will be passed to VCS
# One option per line (lines starting with # are comments)
#
# Loaded automatically by Makefile if this file exists
# ============================================================================

# ============================================================================
# Macro Definitions
# ============================================================================
# Define macros for conditional compilation
+define+SIMULATION
+define+DEBUG_MODE
# +define+FAST_SIM
# +define+ENABLE_ASSERTIONS

# ============================================================================
# Include Directories
# ============================================================================
# Additional include paths (beyond auto-discovered ones)
# +incdir+/path/to/external/includes
# +incdir+../shared/rtl/include

# ============================================================================
# Warning Control
# ============================================================================
# Suppress specific warnings (use cautiously!)
# Format: +warn=<category>

# Suppress "task/function with inout" warnings
# +warn=noTFIPC

# Suppress "implicit port connection" warnings
# +warn=noIPC

# Suppress "unconnected port" warnings
# +warn=noUCONN

# Show all warnings (default)
# -warn=all

# ============================================================================
# Lint Options
# ============================================================================
# Enable lint checks
# +lint=all
# +lint=TFIPC-L

# ============================================================================
# Assertion Options
# ============================================================================
# Enable SystemVerilog Assertions
# -assert svaext

# Enable assertion debug
# -assert enable_diag

# ============================================================================
# Memory/Performance Options
# ============================================================================
# Optimize memory usage
# +memcbk

# Parallel compilation (already set in Makefile, but can override)
# -j16

# ============================================================================
# File Lists
# ============================================================================
# Include external file lists
# -f ../vendor_libs/lib.f
# -f ../common_rtl/rtl.f

# ============================================================================
# Library Mapping
# ============================================================================
# Map library names
# -work my_work_lib
# -libmap my_lib

# ============================================================================
# Verilog/SystemVerilog Standard
# ============================================================================
# Force SystemVerilog 2012
# -sverilog +systemverilogext+.sv

# Mixed Verilog-2001 and SystemVerilog
# +v2k

# ============================================================================
# Debug Options (development phase)
# ============================================================================
# These are already in Makefile, but can be overridden here
# -debug_access+all
# -kdb
# +acc+rw

# ============================================================================
# Code Coverage (if not using COV_ENABLE variable)
# ============================================================================
# Manual coverage enable (normally controlled by Makefile)
# -cm line+cond+fsm+tgl+branch
# -cm_dir ./coverage/simv.vdb

# ============================================================================
# Timing Options
# ============================================================================
# Set timescale (already in Makefile)
# -timescale=1ns/1ps

# Enable timing checks
# +notimingcheck (disable timing checks for faster sim)

# ============================================================================
# Gate-Level Simulation Options
# ============================================================================
# For post-synthesis/post-layout simulation
# +neg_tchk
# -negdelay
# +maxdelays

# SDF back-annotation
# -sdf max:/path/to/design.sdf

# ============================================================================
# Custom User Options
# ============================================================================
# Add your project-specific options below:

# Example: Include your company's standard defines
# +define+COMPANY_STANDARD_VERSION_2023

# Example: Point to shared verification IP
# +incdir+/proj/shared/vip/include

# ============================================================================
# End of file
# ============================================================================