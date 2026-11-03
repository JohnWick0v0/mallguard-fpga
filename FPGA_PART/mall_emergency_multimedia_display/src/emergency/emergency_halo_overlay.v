// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：在四周混合动态警示光晕，按火灾/停电/治安/医疗选择红/白/蓝/黄。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Soft, moving red halo confined to the outer 24 pixels. Combinational RGB,
// so HS/VS/DE/X remain aligned with the existing final subtitle stage.
module emergency_halo_overlay #(
    parameter integer SUPPORT_MULTI_EMERGENCY = 0
)(
    input wire         clk,
                       rst_n,
                       vsync,
                       de,
                       fire_active,
    input wire [2:0]   emergency_kind,
    input wire [9:0]   pixel_x,
    input wire [23:0]  rgb_in,
    output wire [23:0] rgb_out
);
    reg de_q, vs_q;
    reg [9:0] y;
    reg [1:0] divider;
    reg [5:0] phase;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            de_q    <= 0;
            vs_q    <= 1;
            y       <= 0;
            divider <= 0;
            phase   <= 0;
        end else begin
            de_q <= de;
            vs_q <= vsync;
            if (!vsync)
                y <= 0;
            else if (de_q && !de)
                y <= y + 1'b1;
            if (!fire_active) begin
                divider <= 0;
                phase   <= 0;
            end else if (vs_q && !vsync) begin
                if (divider == 2) begin
                    divider <= 0;
                    phase   <= phase + 1'b1;
                end else
                    divider <= divider + 1'b1;
            end
        end
    wire [9:0] dx       = pixel_x < 320 ? pixel_x : 10'd639 - pixel_x;
    wire [9:0] dy       = y < 240 ? y : 10'd479 - y;
    wire [9:0] distance = dx < dy ? dx : dy;
    wire [3:0] alpha;
    emergency_halo_profile_rom u_profile (
        .phase(phase),
        .depth(distance[4:0]),
        .alpha(alpha)
    );
    wire [23:0] target = SUPPORT_MULTI_EMERGENCY ? (emergency_kind == 2      ? 24'hffffff
                                                         : emergency_kind == 3 ? 24'h003388
                                                         : emergency_kind == 4 ? 24'hffd900
                                                                               : 24'hff1624)
                                                   : 24'hff1624;
    // Four explicit shift-add terms avoid increasing DSP use beyond the
    // device's29-block limit when target RGB becomes mode-dependent.
    function [7:0] blend;
        input [7:0] value;
        input [11:0] target_product;
        input [3:0] opacity;
        reg [12:0] source_product, sum;
        begin
            source_product = value * opacity;
            sum            = {1'b0, value, 4'b0} - source_product + target_product;
            blend          = sum[11:4];
        end
    endfunction
    wire [11:0] a             = {8'd0, alpha};
    wire [11:0] full          = (a << 8) - a;
    wire [11:0] red_product   = SUPPORT_MULTI_EMERGENCY && emergency_kind == 3 ? 12'd0 : full;
    wire [11:0] green_product = SUPPORT_MULTI_EMERGENCY && emergency_kind == 2 ? full
                                  : SUPPORT_MULTI_EMERGENCY && emergency_kind == 3
                                      ? (a << 5) + (a << 4) + (a << 1) + a
                                  : SUPPORT_MULTI_EMERGENCY && emergency_kind == 4
                                      ? (a << 7) + (a << 6) + (a << 4) + (a << 3) + a
                                      : (a << 4) + (a << 2) + (a << 1);
    wire [11:0] blue_product =
                      SUPPORT_MULTI_EMERGENCY && emergency_kind == 2   ? full
                      : SUPPORT_MULTI_EMERGENCY && emergency_kind == 3 ? (a << 7) + (a << 3)
                      : SUPPORT_MULTI_EMERGENCY && emergency_kind == 4 ? 12'd0
                                                                       : (a << 5) + (a << 2);
    assign rgb_out = fire_active && de && pixel_x < 640 && y < 480 && distance < 24
                         ? {blend(rgb_in[23:16], red_product, alpha),
                               blend(rgb_in[15:8], green_product, alpha),
                               blend(rgb_in[7:0], blue_product, alpha)}
                         : rgb_in;
endmodule
