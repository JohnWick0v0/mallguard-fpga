// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：专用应急BMP不可用时绘制板内提示页，避免仅留下空白画面。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Until the three user-supplied bitmaps arrive, show a distinct full-frame
// theme and OFF /110 /120. Never display the fire floorplan for other events.
// Pure RGB gate: no extra latency or framebuffer allocation.
module emergency_scene_fallback #(
    parameter integer COMPACT = 0
)(
    input wire         clk,
                       rst_n,
                       vsync,
                       de,
                       active,
    input wire         page_ready,
    input wire [2:0]   kind,
    input wire [9:0]   x,
    input wire [23:0]  rgb_in,
    output wire [23:0] rgb_out
);
    reg de_q;
    reg [9:0] y;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            de_q <= 0;
            y    <= 0;
        end else begin
            de_q <= de;
            if (!vsync)
                y <= 0;
            else if (de_q && !de)
                y <= y + 1'b1;
        end
    wire page                = active && !page_ready && kind >= 2 && kind <= 4 && de;
    wire [23:0] color      = kind == 2 ? 24'hf2f7ff : kind == 3 ? 24'hc8e6ff : 24'hffe066;
    wire [23:0] background = kind == 2 ? 24'h18232d : kind == 3 ? 24'h071b36 : 24'h292413;
    wire [9:0] rx = x - 10'd210, ry = y - 10'd176;
    reg [6:0] segments;
    reg [9:0] cell_x;
    always @* begin
        cell_x   = rx;
        segments = 0;
        if (rx < 70)
            segments = kind == 2 ? 7'h3f : 7'h06;
        else if (rx < 140) begin
            cell_x   = rx - 70;
            segments = kind == 2 ? 7'h71 : kind == 3 ? 7'h06 : 7'h5b;
        end else if (rx < 210) begin
            cell_x   = rx - 140;
            segments = kind == 2 ? 7'h71 : 7'h3f;
        end
    end
    wire on_digit = rx < 210 && ry < 112 &&
                    (segments[0] && cell_x >= 12 && cell_x < 50 && ry < 8 ||
                        segments[1] && cell_x >= 50 && cell_x < 58 && ry >= 8 && ry < 52 ||
                        segments[2] && cell_x >= 50 && cell_x < 58 && ry >= 60 && ry < 104 ||
                        segments[3] && cell_x >= 12 && cell_x < 50 && ry >= 104 ||
                        segments[4] && cell_x >= 4 && cell_x < 12 && ry >= 60 && ry < 104 ||
                        segments[5] && cell_x >= 4 && cell_x < 12 && ry >= 8 && ry < 52 ||
                        segments[6] && cell_x >= 12 && cell_x < 50 && ry >= 52 && ry < 60);
    wire border   = x >= 64 && x < 576 && y >= 116 && y < 364 &&
                    (x < 67 || x >= 573 || y < 119 || y >= 361);
    assign rgb_out =
               page ? (COMPACT ? background : (on_digit || border ? color : background)) : rgb_in;
endmodule
