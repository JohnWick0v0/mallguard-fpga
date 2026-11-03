# 仿真文件、工作库与运行输出分别存放，不向src中写入任何生成文件。
onerror {quit -code 1 -f}
set project_root [file normalize [file join [file dirname [info script]] ..]]
set test_work [file join $project_root sim work modelsim [clock seconds]]
file mkdir $test_work
cd $test_work
vlib work
vmap work [file join $test_work work]
vlog -vlog01compat -work work [file join $project_root src emergency emergency_uart_control.v]
vlog -vlog01compat -work work [file join $project_root src emergency emergency_session_controller.v]
vlog -vlog01compat -work work [file join $project_root sim tb_emergency_uart_control.v]
vsim -onfinish stop work.tb_emergency_uart_control
run -all
quit -code 0 -f
