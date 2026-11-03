// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：PCM跨时钟缓存；通过格雷码指针同步读写位置。
// 时钟：wr_clk、rd_clk。
// 复位：wr_rst_n（低有效异步复位）；rd_rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Full-capacity asynchronous FIFO, extra wrap bit and Gray-pointer crossings.
// Read data is registered one read clock after rd_en (no show-ahead port).
// 设计约定：
// 跨域约定：二进制指针用于本地RAM寻址，格雷码指针经两级同步后判断空/满。
// 读写端只能使用各自时钟域的使能和状态，不以对侧组合信号直接控制本地指针。

module async_pcm_fifo #(
    parameter AW   = 11,
    parameter DW = 32
)(
    input wire            wr_clk,
                          wr_rst_n,
                          wr_en,
    input wire [DW - 1:0] wr_data,
    output wire           full,
    output wire [AW:0]    wr_level,
    input wire            rd_clk,
                          rd_rst_n,
                          rd_en,
    output reg [DW - 1:0] rd_data,
    output wire           empty
);
    reg [DW - 1:0] mem[0:(1 << AW) - 1];
    reg [AW:0] wp, rp, wg, rg, rg1, rg2, wg1, wg2;
    function [AW:0] binary;
        input [AW:0] g;
        integer i;
        begin
            binary[AW] = g[AW];
            for (i = AW - 1; i >= 0; i = i - 1)
                binary[i] = binary[i + 1] ^ g[i];
        end
    endfunction
    wire [AW:0] next_wp = wp + 1'b1;
    assign full           = wg == {~rg2[AW:AW - 1], rg2[AW - 2:0]};
    assign empty          = rg == wg2;
    assign wr_level       = wp - binary(rg2);
    always @(posedge wr_clk)
        if (wr_en && !full)
            mem[wp[AW - 1:0]] <= wr_data;
    always @(posedge rd_clk)
        if (rd_en && !empty)
            rd_data <= mem[rp[AW - 1:0]];
    always @(posedge wr_clk or negedge wr_rst_n)
        if (!wr_rst_n) begin
            wp  <= 0;
            wg  <= 0;
            rg1 <= 0;
            rg2 <= 0;
        end else begin
            rg1 <= rg;
            rg2 <= rg1;
            if (wr_en && !full) begin
                wp <= next_wp;
                wg <= next_wp ^ (next_wp >> 1);
            end
        end
    always @(posedge rd_clk or negedge rd_rst_n)
        if (!rd_rst_n) begin
            rp  <= 0;
            rg  <= 0;
            wg1 <= 0;
            wg2 <= 0;
        end else begin
            wg1 <= wg;
            wg2 <= wg1;
            if (rd_en && !empty) begin
                rp <= rp + 1'b1;
                rg <= (rp + 1'b1) ^ ((rp + 1'b1) >> 1);
            end
        end
endmodule
