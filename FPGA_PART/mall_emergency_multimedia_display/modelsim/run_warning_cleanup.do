# Native wrapper contract versus the previous RTL, including ten VGA frames.
# This entry deliberately does NOT define MALL_RTL_SIMULATION.
onerror {quit -code 1 -f}
set project_root [file normalize [file join [file dirname [info script]] ..]]
set test_work [file join $project_root sim work warning_cleanup [clock seconds]]
file mkdir $test_work
cd $test_work
foreach source {
    src/emergency/emergency_font_rom.dath
    src/display/mall_marquee_font_rom.dath
} {
    file copy -force [file join $project_root $source] [file tail $source]
}
vlib work
vmap work [file join $test_work work]
foreach source {
    sim/warning_cleanup/eg_logic_bram_contract_model.v
    src/emergency/emergency_font_rom.v
    src/display/mall_marquee_font_rom.v
    src/display/brand_watermark_24.v
    src/display/audio_envelope_visualizer.v
    sim/warning_cleanup/emergency_font_rom_reference.v
    sim/warning_cleanup/mall_marquee_font_rom_reference.v
    sim/warning_cleanup/brand_watermark_24_reference.v
    sim/warning_cleanup/audio_envelope_visualizer_reference.v
} {
    vlog -work work [file join $project_root $source]
}
vlog -sv -work work [file join $project_root sim warning_cleanup tb_warning_cleanup.sv]
vsim -onfinish stop work.tb_warning_cleanup
run -all
quit -code 0 -f
