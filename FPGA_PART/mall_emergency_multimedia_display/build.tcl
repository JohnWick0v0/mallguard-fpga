# Reproducible build entry for TD 6.2 / EG4S20BG256.
# Run in the TD Tcl Console: source <this project>/build.tcl
# Only publish the release BIT after both routed timing checks pass.
set project_root [file normalize [file dirname [info script]]]
cd $project_root
import_device eagle_s20.db -package EG4S20BG256
open_project mall_emergency_multimedia_display.al
source [file join $project_root configure_project.tcl]

proc mall_read_file {path} {
    set handle [open $path r]
    set data [read $handle]
    close $handle
    return $data
}
proc mall_check_run {directory marker} {
    if {![file isfile [file join $directory $marker]]} {
        error "Run incomplete: $directory; inspect run.log"
    }
    set data [mall_read_file [file join $directory run.log]]
    if {[regexp {(ERROR:|CRITICAL-ERROR:)} $data]} {
        error "Run reported an error: $directory; BIT not published"
    }
    return $data
}

set syn_dir [file join $project_root mall_emergency_multimedia_display_Runs syn_1]
set phy_dir [file join $project_root mall_emergency_multimedia_display_Runs phy_1]
# Explicit reset prevents a green completion flag from an older failed build
# being mistaken for success. Native TD clears only its own run products.
reset_runs syn_1
launch_runs syn_1
wait_run syn_1
set syn_log [mall_check_run $syn_dir .opt_gate.end.f]
if {[regexp {SYN-6562} $syn_log] ||
    ![regexp {eram_init\s*\|\s*on\s*\|} $syn_log] ||
    ![regexp {pack_seq_in_io\s*\|\s*off\s*\|} $syn_log]} {
    error "RAM initialization is not enabled in the REAL synthesis run"
}
puts "MALL_SYNTHESIS_PASS: RAM initialization verified in child run.log"

# Reapply after synthesis; do not rely on a previous GUI session's values.
source [file join $project_root configure_project.tcl]
reset_runs phy_1
launch_runs phy_1
wait_run phy_1
set phy_log [mall_check_run $phy_dir .bitgen.end.f]
if {![regexp {set_param place seed 36} $phy_log] ||
    ![regexp {set_param flow thread 8} $phy_log] ||
    ![regexp {set_param route effort routability} $phy_log]} {
    error "Physical run did not apply required seed/thread/routing settings"
}
source [file join $project_root finish_implementation.tcl]
