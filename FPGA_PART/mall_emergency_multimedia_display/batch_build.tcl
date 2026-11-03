# Entry used by build.cmd. Keep GUI source build.tcl separate: a GUI session
# must not be closed when a Tcl error is reported.
if {[catch {source [file join [file dirname [info script]] build.tcl]} message]} {
    puts stderr "MALL_BUILD_FAILED: $message"
    exit 1
}
exit
