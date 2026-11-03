// SDRAM公共参数；各使用文件必须显式include，不能作为独立模块参与综合。
`ifndef MALL_SDRAM_GLOBAL_DEF_VH
`define MALL_SDRAM_GLOBAL_DEF_VH
`define   DATA_WIDTH                        32
`define   ADDR_WIDTH                        21
`define   DM_WIDTH                          4

`define   ROW_WIDTH                        11
`define   BA_WIDTH                        2

// Parenthesize both macros: textual substitution must preserve division order.
// At 40 MHz with 2048 rows: 25 ns per clock, 1250 clocks per refresh slot.
`define   SDR_CLK_PERIOD                   (1000000000 / 40000000)
`define   SELF_REFRESH_INTERVAL            (64000000 / `SDR_CLK_PERIOD / (2 ** (`ROW_WIDTH)))
`endif
