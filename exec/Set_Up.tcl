#!/usr/bin/env tclsh

# Check required directories and files
if {![file exists ./work]}  {
    file mkdir ./work
}
if {![file exists ./setup]} {
    error "missing ./setup directory"
}
if {![file exists ./setup/library.lst]} {
    error "missing ./setup/library.lst"
}

set DATE [clock format [clock seconds] -format %Y%m%d_%H%M]

proc unique {BeforeUni} {
    array unset uniarr
    set AfterUni {}
    foreach e $BeforeUni {
        if {![info exists uniarr($e)]} {
            lappend AfterUni $e
            set uniarr($e) 1
        }
    }
    return $AfterUni
}

# 新增：检查库文件是否存在的函数
proc find_library_file {libname search_paths} {
    # 首先在 ../lib/ 目录下查找
    set scriptDir [file dirname [file normalize [info script]]]
    set parentDir [file dirname $scriptDir]
    set libDir [file join $parentDir lib]
    set libPath [file join $libDir $libname]
    
    if {[file exists $libPath]} {
        puts "Debug: Found library $libname in lib directory: $libPath"
        return $libPath
    }
    
    # 在搜索路径中查找
    foreach path $search_paths {
        set fullPath [file join $path $libname]
        if {[file exists $fullPath]} {
            puts "Debug: Found library $libname in search path: $fullPath"
            return $fullPath
        }
    }
    
    # 如果都找不到，返回库名让DC在搜索路径中查找
    puts "Debug: Library $libname not found in local paths, will use library name for DC search"
    return $libname
}

# Read input file
set fileToRead  [open ./setup/library.lst r]
set fileToWrite [open ./work/script.tcl w]

# Initialize variables
set search_path {}
set library_file {}
set link_file {}
set symbolLibraries {}
set syntheticLibraries {}
set top_module ""
set incdir {}
set library_file_wc {}
set worst_condition ""

puts "Debug: Starting to read library.lst"

while {[gets $fileToRead line] >= 0} {
    # 替换全角冒号为半角冒号
    regsub -all {\uFF1A} $line {:} line
    # 替换全角空格为半角空格
    regsub -all {\u3000} $line { } line
    # 替换非断空格
    regsub -all {\u00A0} $line { } line
    # 去掉注释和首尾空白
    set line [string trim [lindex [split $line "#"] 0]]
    
    # 跳过空行
    if {$line eq ""} {
        continue
    }
    
    puts "Debug: Processing line: $line"

    if {[regexp -nocase {^\s*LibraryPath\s*:\s*(.+)$} $line _ LibraryPath]} {
        set LibraryPath [string trim $LibraryPath]
        lappend search_path $LibraryPath
        puts "Debug: LibraryPath: $LibraryPath"
        continue
    }

    if {[regexp -nocase {^\s*LibraryFile\s*:\s*(.+)$} $line _ LibraryFile]} {
        set LibraryFile [string trim $LibraryFile]
        lappend library_file $LibraryFile
        puts "Debug: LibraryFile: $LibraryFile"
        continue
    }

    if {[regexp -nocase {^\s*LinkLibraryFile\s*:\s*(.+)$} $line _ LinkFile]} {
        set LinkFile [string trim $LinkFile]
        lappend link_file $LinkFile
        puts "Debug: LinkLibraryFile: $LinkFile"
        continue
    }

    if {[regexp -nocase {^\s*SymbolLibrary\s*:\s*(.+)$} $line _ sdbRaw]} {
        set sdb [string trim $sdbRaw]
        lappend symbolLibraries $sdb
        puts "Debug: SymbolLibrary: $sdb"
        continue
    }

    if {[regexp -nocase {^\s*SyntheticLibrary\s*:\s*(.+)$} $line _ sldbRaw]} {
        set sldb [string trim $sldbRaw]
        lappend syntheticLibraries $sldb
        puts "Debug: SyntheticLibrary: $sldb"
        continue
    }

    if {[regexp -nocase {^\s*TopModule\s*:\s*(.+)$} $line _ TopModule]} {
        set top_module [string trim $TopModule]
        puts "Debug: TopModule: $top_module"
        continue
    }

    # 新增：处理 Incdir
    if {[regexp -nocase {^\s*Incdir\s*:\s*(.+)$} $line _ IncDir]} {
        set IncDir [string trim $IncDir]
        lappend incdir $IncDir
        puts "Debug: Incdir: $IncDir"
        continue
    }

    # 新增：处理 LibraryFile_WC
    if {[regexp -nocase {^\s*LibraryFile_WC\s*:\s*(.+)$} $line _ LibraryFileWC]} {
        set LibraryFileWC [string trim $LibraryFileWC]
        lappend library_file_wc $LibraryFileWC
        puts "Debug: LibraryFile_WC: $LibraryFileWC"
        continue
    }

    # 新增：处理 WorstCondition
    if {[regexp -nocase {^\s*WorstCondition\s*:\s*(.+)$} $line _ WorstCond]} {
        set worst_condition [string trim $WorstCond]
        puts "Debug: WorstCondition: $worst_condition"
        continue
    }
}

close $fileToRead

# Check for required top_module
if {$top_module eq ""} {
    error "TopModule not specified in library.lst"
}

# Remove duplicates
set search_path        [unique $search_path]
set library_file       [unique $library_file]
set link_file          [unique $link_file]
set symbolLibraries    [unique $symbolLibraries]
set syntheticLibraries [unique $syntheticLibraries]
set incdir             [unique $incdir]
set library_file_wc    [unique $library_file_wc]

puts "Debug: search_path = $search_path"
puts "Debug: library_file = $library_file"
puts "Debug: link_file = $link_file"
puts "Debug: symbolLibraries = $symbolLibraries"
puts "Debug: syntheticLibraries = $syntheticLibraries"

# 改进的库文件路径处理逻辑
set processed_library_file {}
set processed_link_file {}

# 处理主库文件
foreach lf $library_file {
    set resolved_path [find_library_file $lf $search_path]
    lappend processed_library_file $resolved_path
}

# 处理链接库文件
foreach lf $link_file {
    set resolved_path [find_library_file $lf $search_path]
    lappend processed_link_file $resolved_path
}

puts "Debug: processed_library_file = $processed_library_file"
puts "Debug: processed_link_file = $processed_link_file"

# Write output script
puts $fileToWrite "# Auto-generated by Tcl Script"
puts $fileToWrite [format "# Generated at %s" [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]]
puts $fileToWrite ""
puts $fileToWrite "######### Set Library (for dc_shell -t) ###########"
puts $fileToWrite "remove_design -all"
puts $fileToWrite "set_host_options -max_cores 16"
puts $fileToWrite "set_svf  ../output/${top_module}_${DATE}.svf"
puts $fileToWrite ""

# 设置搜索路径（包含include目录）
set all_search_paths [concat $search_path $incdir]
if {[llength $all_search_paths] > 0} {
    puts $fileToWrite "set_app_var search_path \"[join $all_search_paths \" \"]\""
}

# 设置目标库
if {[llength $processed_library_file] > 0} {
    puts $fileToWrite "set_app_var target_library \"[join $processed_library_file \" \"]\""
}

# 设置链接库
set all_link_libs [concat $processed_library_file $processed_link_file $symbolLibraries $syntheticLibraries]
if {[llength $all_link_libs] > 0} {
    puts $fileToWrite "set_app_var link_library \"* [join $all_link_libs \" \"]\""
}

# 设置符号库
if {[llength $symbolLibraries] > 0} {
    puts $fileToWrite "set_app_var symbol_library \"[join $symbolLibraries \" \"]\""
}

# 设置合成库
if {[llength $syntheticLibraries] > 0} {
    puts $fileToWrite "set_app_var synthetic_library \"[join $syntheticLibraries \" \"]\""
}

puts $fileToWrite ""
puts $fileToWrite "# Top module: $top_module"
if {$worst_condition ne ""} {
    puts $fileToWrite "# Worst condition: $worst_condition"
}

close $fileToWrite

puts "Debug: Script generation completed successfully"
puts "Generated script saved to: ./work/script.tcl"