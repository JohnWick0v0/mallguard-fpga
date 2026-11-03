# mall_emergency_multimedia_display

本目录为安路TD工程，平台HX4S20C / EG4S20BG256。RTL顶层：`mall_guard_display_top`。

- `src`：按audio、clock、common、control、display、emergency、filesystem、flash、hdmi、image、key、notice、pipeline、sdram、storage、top、uart、video划分。
- `constrainsts`：`top.adc`引脚约束、`top.sdc`时序约束，保留原目录拼写。
- `sim`：测试平台与接口模型；`modelsim`：对应运行脚本。
- `release`：既有下载BIT、原始资源及时序报告、构建校验记录。

设置 `TD_HOME` 后运行 `build.cmd`，或在TD Tcl Console切换至本目录执行 `source build.tcl`。
`.al`文件使用相对工程路径；所有HDL与约束路径保持相对路径。请完整解压提交包后构建。
`build.tcl`以自身位置定位工程，不依赖原来的Final_test_3目录。

完整构建会重新综合、布局布线、独立修复保持时间，校验RAM初始化及建立/保持结果，成功后输出 `MALL_BUILD_PASS:`。
若仅点击TD默认流程，尚未保证执行 `finish_implementation.tcl` 中的独立保持修复；下载时以完整构建后的 `release` 文件为准。

字模 `.dath` 是硬件初始化所需数据，必须与对应模块同目录。TD硬件综合不得定义 `MALL_RTL_SIMULATION`。
普通RTL功能仿真可使用该宏；`modelsim/run_warning_cleanup.do`使用原生接口模型进行逐拍对照，不定义此宏。
在ModelSim Console执行 `do modelsim/run_uart.do`、`do modelsim/run_flash_crc.do` 或 `do modelsim/run_warning_cleanup.do`。
模型仿真不能替代厂商原语及板级验证。

配套TF卡文件统一位于 `../../HOSTPC_PART/MallGuardConsole/release/assets`，只复制BMP、WAV、BIN至卡根目录。
详见 `docs/BUILD_NOTES.md` 与 `release/VERIFICATION.json`。
