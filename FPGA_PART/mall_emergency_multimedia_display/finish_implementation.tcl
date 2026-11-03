# 商安视界：在布线数据库上校核真实CRC捕获窗口，修复保持时间并生成发布BIT。
# GUI布局布线结束后可单独source本文件；build.tcl会自动调用本步骤。
set mall_project_root [file normalize [file dirname [info script]]]
set mall_impl_dir [file join $mall_project_root mall_emergency_multimedia_display_Runs phy_1]
set mall_release_dir [file join $mall_project_root release]
file mkdir $mall_release_dir
package require sha256
cd $mall_project_root
# Standalone GUI use must reject a database built with lost RAM settings.
foreach {mall_stage mall_required} {
    syn_1 .opt_gate.end.f
    phy_1 .bitgen.end.f
} {
    set mall_run_dir [file join $mall_project_root mall_emergency_multimedia_display_Runs $mall_stage]
    if {![file isfile [file join $mall_run_dir $mall_required]]} {
        error "Incomplete $mall_stage; run source build.tcl first"
    }
    set mall_handle [open [file join $mall_run_dir run.log] r]
    set mall_run_log [read $mall_handle]
    close $mall_handle
    if {[regexp {ERROR:} $mall_run_log]} {
        error "Errors found in $mall_stage/run.log; database rejected"
    }
    if {$mall_stage eq "syn_1" &&
        ([regexp {SYN-6562} $mall_run_log] ||
         ![regexp {eram_init\s*\|\s*on\s*\|} $mall_run_log] ||
         ![regexp {pack_seq_in_io\s*\|\s*off\s*\|} $mall_run_log])} {
        error "RAM initialization was not enabled; rebuild using build.tcl"
    }
}
if {[regexp {PHY-5079} $mall_run_log]} {
    error "Local clock routing was detected; do not publish this implementation"
}
import_device eagle_s20.db -package EG4S20BG256
import_db [file join $mall_impl_dir mall_emergency_multimedia_display_pr.db]
end_timer
clear_sdc -user
read_sdc [file join $mall_project_root constrainsts top.sdc]
set_param flow thread 8
# TD默认GUI流程没有保证在最终数据库上执行独立fix_hold，必须显式完成。
fix_hold
update_timing -mode final
set mall_timing_file [file join $mall_release_dir mall_emergency_multimedia_display_pr.timing]
# TD 6.2的报告文件参数使用工作目录下的字面文件名，避免绝对路径选项失效。
cd $mall_release_dir
report_timing_summary -file mall_emergency_multimedia_display_pr.timing
report_area -io_info -file mall_emergency_multimedia_display_phy.area
cd $mall_impl_dir
report_param -all -detail -file final_applied_params.txt
report_route_status -drc
# Check the repaired database itself, including abnormal timing and drivers.
# TD writes diagnostics into the console/run log; retain warnings verbatim.
drc_check -route -verbose
set mall_tf [open $mall_timing_file r]
set mall_timing_data [read $mall_tf]
close $mall_tf
if {![regexp {SWNS:\s*(-?[0-9.]+)ns} $mall_timing_data -> mall_setup] ||
    ![regexp {HWNS:\s*(-?[0-9.]+)ns} $mall_timing_data -> mall_hold]} {
    error "Missing final setup/hold timing report"
}
if {$mall_setup < 0 || $mall_hold < 0} {
    error "Timing not closed: setup=$mall_setup ns, hold=$mall_hold ns; BIT not published"
}
export_db repaired_pr.db
write_verilog repaired_mapped.v
cd $mall_release_dir
bitgen -bit mall_emergency_multimedia_display.pending.bit
file rename -force mall_emergency_multimedia_display.pending.bit mall_emergency_multimedia_display.bit
# Generate a fresh build identity on EVERY successful build. The SHA-256
# binds the routed timing report, sources and published BIT to this run.
proc mall_source_files {directory} {
    set result {}
    foreach item [lsort [glob -nocomplain -directory $directory *]] {
        if {[file isdirectory $item]} {
            set result [concat $result [mall_source_files $item]]
        } elseif {[file extension $item] in {.v .vh .adc .sdc .dath}} {
            lappend result $item
        }
    }
    return $result
}
set mall_bit_path [file join $mall_release_dir mall_emergency_multimedia_display.bit]
set mall_bit_sha [::sha2::sha256 -hex -filename $mall_bit_path]
set mall_source_pairs {}
foreach mall_source [concat [mall_source_files [file join $mall_project_root src]] \
    [mall_source_files [file join $mall_project_root constrainsts]]] {
    set mall_relative [string range [file normalize $mall_source] [expr {[string length $mall_project_root]+1}] end]
    lappend mall_source_pairs [format {"%s":"%s"} $mall_relative [::sha2::sha256 -hex -filename $mall_source]]
}
set mall_record [open [file join $mall_release_dir BUILD_RESULT.json] w]
puts $mall_record "\{"
puts $mall_record {  "project":"mall_emergency_multimedia_display",}
puts $mall_record [format {  "generated_utc":"%s",} [clock format [clock seconds] -gmt true -format {%Y-%m-%dT%H:%M:%SZ}]]
puts $mall_record [format {  "setup_wns_ns":%s,"hold_wns_ns":%s,} $mall_setup $mall_hold]
puts $mall_record [format {  "bit_sha256":"%s","bit_bytes":%d,} $mall_bit_sha [file size $mall_bit_path]]
puts $mall_record [format {  "source_sha256":{%s}} [join $mall_source_pairs ,]]
puts $mall_record "\}"
close $mall_record
puts "MALL_BUILD_PASS: setup=$mall_setup ns, hold=$mall_hold ns"
