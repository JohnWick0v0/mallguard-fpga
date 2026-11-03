// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：对RGB像素执行对比度处理，并保持HS/VS/DE/X与数据流水一致。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Unsigned multiplier candidate; RGB bundle latency is unchanged.
// 设计约定：
// 对齐约定：对比度运算与HS/VS/DE/X在同一组流水级推进，禁止仅调整像素数据延迟。

module color_adjust_pipeline (
    input wire        clk,
                      rst_n,
    input wire        hs_in,
                      vs_in,
                      de_in,
    input wire [9:0]  x_in,
    input wire [23:0] rgb_in,
    input wire [7:0]  contrast,
    output reg        hs_out,
                      vs_out,
                      de_out,
    output reg [9:0]  x_out,
    output reg [23:0] rgb_out
);
    reg vs_q;
    reg [7:0] contrast_q;
    function [7:0] adjust;
        input [7:0] value, gain;
        reg [15:0] product;
        reg [16:0] biased, bias, level;
        begin
            // All multiplier operands are nonnegative. Apply the midpoint correction
            // afterwards; no signed DSP operation can be packed with an address product.
            product = value * gain;
            biased  = {1'b0, product} + 17'd16384;
            bias    = {2'b00, gain, 7'b0};
            if (biased < bias)
                adjust = 0;
            else begin
                level  = biased - bias;
                adjust = level >= 17'd32640 ? 8'd255 : level[14:7];
            end
        end
    endfunction
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            vs_q       <= 1;
            contrast_q <= 128;
            hs_out     <= 1;
            vs_out     <= 1;
            de_out     <= 0;
            x_out      <= 0;
            rgb_out    <= 0;
        end else begin
            vs_q <= vs_in;
            if (vs_q && !vs_in)
                contrast_q <= contrast;
            hs_out  <= hs_in;
            vs_out  <= vs_in;
            de_out  <= de_in;
            x_out   <= x_in;
            rgb_out <= de_in ? {adjust(rgb_in[23:16], contrast_q),
                                   adjust(rgb_in[15:8], contrast_q),
                                   adjust(rgb_in[7:0], contrast_q)}
                             : 24'd0;
        end
endmodule
