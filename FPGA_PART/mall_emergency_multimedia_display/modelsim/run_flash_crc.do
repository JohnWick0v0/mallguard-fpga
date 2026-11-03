# 两份Flash参数记录的CRC捕获窗口回归；验证第一拍结果错误时仍能正确载入/保存。
set project_root [file normalize [file join [file dirname [info script]] ..]]
set work_root [file join $project_root sim work flash_crc]
file mkdir $work_root
cd $work_root
onerror {quit -code 1}
vlib work
vmap work work
vlog -vlog01compat [file join $project_root src flash config_journal.v]
vlog -vlog01compat [file join $project_root src flash config_flash_journal.v]
vlog -sv [file join $project_root sim tb_flash_crc_windows.sv]
vsim -c work.tb_flash_crc_windows
run -all
quit -code 0
