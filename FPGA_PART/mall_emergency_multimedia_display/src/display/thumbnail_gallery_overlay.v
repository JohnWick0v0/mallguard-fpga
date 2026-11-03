// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：四宫格缩略图叠加与黄色焦点边框，帧边界同步界面状态。
// 时钟：pix_clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// The input RGB is now the full-color SDRAM gallery, already at native
// 640x480. Only draw the selected 320x240 tile's border; do not rescale RGB.
// Full-screen and gallery paths both retain the original one-clock delay.
module thumbnail_gallery_overlay (
    input wire         pix_clk,
                       rst_n,
                       hs_in,
                       vs_in,
                       de_in,
    input wire [9:0]   x_in,
    input wire [23:0]  rgb_in,
    input wire         view_mode,
    input wire [1:0]   focus_index,
    output reg         hs_out,
                       vs_out,
                       de_out,
    output reg [9:0]   x_out,
    output wire [23:0] rgb_out
);
    reg vs_q, de_q;
    reg [9:0] y;
    reg mode_q, mode_d, border_q;
    reg [1:0] focus_q;
    reg [23:0] rgb_q;
    wire [1:0] tile = (y >= 240 ? 2'd2 : 2'd0) + (x_in >= 320 ? 2'd1 : 2'd0);
    wire [9:0] lx   = x_in >= 320 ? x_in - 10'd320 : x_in;
    wire [9:0] ly   = y >= 240 ? y - 10'd240 : y;
    wire border       = de_in && x_in < 640 && y < 480 && tile == focus_q &&
                        (lx < 2 || lx >= 318 || ly < 2 || ly >= 238);
    always @(posedge pix_clk or negedge rst_n) begin
        if (!rst_n) begin
            vs_q     <= 1;
            de_q     <= 0;
            y        <= 0;
            mode_q   <= 0;
            focus_q  <= 0;
            hs_out   <= 1;
            vs_out   <= 1;
            de_out   <= 0;
            x_out    <= 0;
            rgb_q    <= 0;
            mode_d   <= 0;
            border_q <= 0;
        end else begin
            vs_q <= vs_in;
            de_q <= de_in;
            if (!vs_in)
                y <= 0;
            else if (de_q && !de_in)
                y <= y + 1'b1;
            if (vs_q && !vs_in) begin
                mode_q  <= view_mode;
                focus_q <= focus_index;
            end
            hs_out   <= hs_in;
            vs_out   <= vs_in;
            de_out   <= de_in;
            x_out    <= x_in;
            rgb_q    <= rgb_in;
            mode_d   <= mode_q;
            border_q <= border;
        end
    end
    assign rgb_out = !de_out ? 24'd0 : mode_d && border_q ? 24'hffff00 : rgb_q;
endmodule
