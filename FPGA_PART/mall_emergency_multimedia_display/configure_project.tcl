# Always apply essential settings in the active TD project manager.
# A GUI save/default strategy reset can omit non-default XML fields. The
# build entry sources this file on EVERY build, before launching child runs.
set_param gate eram_init on -run syn_1
# Bound synthesis concurrency to avoid exhausting Windows commit memory.
set_param flow thread 2 -run syn_1
# TD 6.2 emits spurious undriven RTL-clock diagnostics after I/O FF packing.
# Keep these FFs in fabric and retain their real clocks for timing analysis.
set_param gate pack_seq_in_io off -run syn_1
set_param gate map_mode area_prior -run syn_1
set_param rtl min_ripple_len 36 -run syn_1
set_param flow thread 8 -run phy_1
set_param place effort high -run phy_1
# EG4 does not support pre-route hold fixing (OPT-5502). Repair hold on the
# routed database in finish_implementation.tcl instead.
set_param place fix_hold off -run phy_1
set_param place opt_timing high -run phy_1
set_param place post_place_opt high -run phy_1
set_param place seed 36 -run phy_1
set_param route post_route_opt high -run phy_1
set_param route hold_fix_iteration 20 -run phy_1
# Dense EG4S20 routing needs violation-resolution effort in ECO reroutes too.
# TD PHY-8080 recommends routability when normal effort leaves overlaps.
set_param route effort routability -run phy_1
# Run-specific UserParams are replayed in child processes after defaults.
# A minimal TD run verified these survive non_default_params -revert.
set_user_params -run syn_1 -params {
    {flow thread 2}
    {gate eram_init on}
    {gate pack_seq_in_io off}
    {gate map_mode area_prior}
    {rtl min_ripple_len 36}
}
set_user_params -run phy_1 -params {
    {flow thread 8}
    {place effort high}
    {place opt_timing high}
    {place post_place_opt high}
    {place seed 36}
    {place fix_hold off}
    {route post_route_opt high}
    {route hold_fix_iteration 20}
    {route effort routability}
}
if {[get_param gate eram_init -run syn_1] ne "on" ||
    [get_param gate pack_seq_in_io -run syn_1] ne "off" ||
    [get_param place seed -run phy_1] ne "36" ||
    [get_param route effort -run phy_1] ne "routability"} {
    error "TD project manager did not accept the required build profile"
}
puts "MALL_CONFIG_APPLIED: eram_init=on, seed=36, physical_threads=8, route_effort=routability"
