// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：基础异步FIFO存储及指针同步实现，复用既有接口时序。
// 时钟：rd_clk、wr_clk。
// 复位：rd_rst_n（低有效异步复位）；wr_rst_n（向子模块传递，语义见子模块）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Registered RAM FIFO plus the inherited two-word prefetch stage.
// 设计约定：
// 写口运行于wr_clk，读口运行于rd_clk；下层RAM读延迟由rv和两级预取器吸收。

module demo_fifo #(
    parameter AW = 9,
              DW = 32
)(
    input wire             wr_clk,
                           wr_rst_n,
                           push,
    input wire [DW - 1:0]  data,
    output wire            full,
    output wire [AW:0]     level,
    input wire             rd_clk,
                           rd_rst_n,
                           pop,
    output wire            valid,
    output wire [DW - 1:0] head
);
    wire empty, re;
    wire [DW - 1:0] raw;
    reg rv;
    async_pcm_fifo #(
        .AW(AW),
        .DW(DW)
    ) u_ram (
        .wr_clk(wr_clk),
        .wr_rst_n(wr_rst_n),
        .wr_en(push),
        .wr_data(data),
        .full(full),
        .wr_level(level),
        .rd_clk(rd_clk),
        .rd_rst_n(rd_rst_n),
        .rd_en(re),
        .rd_data(raw),
        .empty(empty)
    );
    always @(posedge rd_clk or negedge rd_rst_n)
        if (!rd_rst_n)
            rv <= 0;
        else
            rv <= re && !empty;
    fifo_prefetch_2 #(
        .DATA_WIDTH(DW)
    ) u_prefetch (
        .clk(rd_clk),
        .rst(!rd_rst_n),
        .raw_empty(empty),
        .raw_valid(rv),
        .raw_data(raw),
        .raw_read_en(re),
        .consume(pop),
        .out_valid(valid),
        .out_empty(),
        .out_data(head)
    );
endmodule
