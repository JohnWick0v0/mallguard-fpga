// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：配套VIDEO.BIN布局常量：640画布、160帧、10fps、16秒；须与TF媒体同步更新。
// 时钟：组合查询/透传接口，时序由调用方或子模块确定。
// 复位：本模块无复位端口或本地复位分支。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`ifndef CLIP_LAYOUT_VH
`define CLIP_LAYOUT_VH
`define CLIP_FRAMES 160
`define CLIP_BYTES 19988992
`define CLIP_FRAME_BYTES 124928
`define CLIP_FRAME_WORDS 31232
`define CLIP_VIDEO_BYTES 115200
`define CLIP_VIDEO_WORDS 28800
`define CLIP_AUDIO_WORDS 2400
`define CLIP_FRAME_SAMPLES 4800
`define CLIP_HEADER_CRC 32'hcd5baec2
`define CLIP_RING_SLOTS 16
`endif
