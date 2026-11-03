// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：在画面上方滚动商场或应急中文字幕，提供淡化底色与隐藏控制。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// Top scrolling mall subtitle:
// "欢迎光临  安全购物  美好生活"
//
// Each Chinese glyph is a 24x24 bitmap inside a 32-pixel cell. The banner is
// placed below the status OSD and moves left by SCROLL_STEP pixels per frame.
// RGB and the complete timing bundle are delayed by exactly one pixel clock.
module mall_marquee_overlay #(
    parameter integer SUPPORT_FIRE              = 0,
    parameter integer SUPPORT_MULTI_EMERGENCY = 0,
    parameter integer SUPPORT_BRAM_FONT       = 0,
    parameter integer SUPPORT_HIDE            = 0,
    parameter integer FIRE_Y                  = 28,
    parameter integer SUB_Y                   = 32,
    parameter integer SCROLL_STEP             = 2,
    parameter integer H_ACT                   = 640,
    parameter [23:0]  TEXT_COLOR             = 24'hFFD966,
    parameter [23:0]  BANNER_COLOR           = 24'h102840
)(
    input wire         clk,
    input wire         rst_n,
    input wire         fire_active,
    input wire [2:0]   emergency_kind,
    input wire         hide_overlay,
    input wire         hsync,
    input wire         vsync,
    input wire         de,
    input wire [9:0]   pixel_x,
    input wire [23:0]  rgb_in,
    output reg         hsync_out,
    output reg         vsync_out,
    output reg         de_out,
    output reg [9:0]   pixel_x_out,
    output wire [23:0] rgb_out,
    output wire        subtitle_active
);
    localparam integer GLYPH_W     = 24;
    localparam integer GLYPH_H     = 24;
    localparam integer CELL_W      = 32;
    localparam integer GLYPH_COUNT = 14;
    localparam integer TEXT_W      = CELL_W * GLYPH_COUNT;
    localparam integer SPAN        = H_ACT + TEXT_W;
    localparam integer START_X     = 64;
    localparam integer START_POS   = H_ACT - START_X;

    localparam [9:0] H_ACT_R      = H_ACT;
    localparam [11:0] SUB_Y_R     = SUB_Y;
    localparam [11:0] GLYPH_H_R   = GLYPH_H;
    localparam [11:0] TEXT_W_R    = TEXT_W;
    localparam [10:0] SPAN_R      = SPAN;
    localparam [10:0] STEP_R      = SCROLL_STEP;
    localparam [10:0] START_POS_R = START_POS;

    reg [10:0] scroll_pos;
    reg [10:0] fire_scroll_pos;
    wire alarm           = SUPPORT_FIRE && fire_active;
    wire [11:0] band_y = alarm ? FIRE_Y : SUB_Y_R;
    wire visible         = !(SUPPORT_HIDE && hide_overlay);
    wire [11:0] dynamic_text_width;
    wire [23:0] dynamic_text_color, multi_font_row;
    wire [10:0] multi_font_address;
    wire [2:0] text_mode   = alarm ? emergency_kind : 3'd0;
    wire [11:0] text_width = SUPPORT_MULTI_EMERGENCY ? dynamic_text_width
                               : alarm                 ? 12'd864
                                                       : TEXT_W_R;
    reg [11:0] line_y;
    reg de_q;
    reg vs_q;
    wire frame_start = vs_q && !vsync;

    // Signed 12-bit math covers the complete range from -447 to +1086.
    wire signed [11:0] banner_x = $signed({2'b00, H_ACT_R}) -
                                    $signed({1'b0, alarm ? fire_scroll_pos : scroll_pos});
    wire signed [11:0] diff     = $signed({2'b00, pixel_x}) - banner_x;
    wire y_band                   = de && (line_y >= band_y) && (line_y < band_y + GLYPH_H_R);
    wire in_text                  = y_band && (diff >= 0) && (diff < text_width);
    wire [3:0] glyph_index      = diff[8:5];
    wire [4:0] glyph_col        = diff[4:0];
    wire [4:0] glyph_row        = line_y - band_y;

    generate
        if (SUPPORT_MULTI_EMERGENCY) begin : g_multi_text
            emergency_text_map u_map (
                .mode(text_mode),
                .position(diff[10:5]),
                .row(glyph_row),
                .address(multi_font_address),
                .text_width(dynamic_text_width),
                .color(dynamic_text_color)
            );
            emergency_font_rom u_rom (
                .clk(clk),
                .address(multi_font_address),
                .row_bits(multi_font_row)
            );
        end else begin : g_legacy_text
            assign multi_font_address = 0;
            assign multi_font_row     = 0;
            assign dynamic_text_width = 0;
            assign dynamic_text_color = TEXT_COLOR;
        end
    endgenerate
    wire [23:0] normal_font_row_bits, fire_font_row_bits;
    wire [23:0] font_row_bits = alarm ? fire_font_row_bits : normal_font_row_bits;
    generate
        if (SUPPORT_FIRE) begin : g_fire_font
            fire_warning_font_24 u_font (
                .glyph_index(diff[10:5]),
                .glyph_row(glyph_row),
                .row_bits(fire_font_row_bits)
            );
        end else begin : g_no_fire_font
            assign fire_font_row_bits = 24'd0;
        end
    endgenerate
    mall_marquee_glyphs u_mall_subtitle_font (
        .glyph_index(glyph_index),
        .glyph_row(glyph_row),
        .row_bits(normal_font_row_bits)
    );

    wire [23:0] bram_row;
    wire [5:0] rom_glyph = alarm ? 6'd14 + diff[10:5] : {2'b00, glyph_index};
    wire [9:0] rom_address =
                     ({4'd0, rom_glyph} << 4) + ({4'd0, rom_glyph} << 3) + {5'd0, glyph_row};
    generate
        if (SUPPORT_BRAM_FONT) begin : g_font_rom
            mall_marquee_font_rom u_rom (
                .clk(clk),
                .address(rom_address),
                .row_bits(bram_row)
            );
        end else begin : g_no_font_rom
            assign bram_row = 24'd0;
        end
    endgenerate
    reg [23:0] rgb_q;
    reg [23:0] glyph_row_q;
    wire [23:0] displayed_row = SUPPORT_MULTI_EMERGENCY ? multi_font_row
                                  : SUPPORT_BRAM_FONT     ? bram_row
                                                          : glyph_row_q;
    reg [23:0] color_q;
    reg alarm_q;
    reg [4:0] glyph_col_q;
    reg text_bounds_q;
    reg banner_band_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hsync_out       <= 1'b1;
            vsync_out       <= 1'b1;
            de_out          <= 1'b0;
            pixel_x_out     <= 10'd0;
            rgb_q           <= 24'd0;
            color_q         <= TEXT_COLOR;
            alarm_q         <= 0;
            glyph_row_q     <= 24'd0;
            glyph_col_q     <= 5'd0;
            text_bounds_q   <= 1'b0;
            banner_band_q   <= 1'b0;
            scroll_pos      <= START_POS_R;
            fire_scroll_pos <= H_ACT - (SUPPORT_MULTI_EMERGENCY ? 32 : 16);
            line_y          <= 12'd0;
            de_q            <= 1'b0;
            vs_q            <= 1'b1;
        end else begin
            hsync_out   <= hsync;
            vsync_out   <= vsync;
            de_out      <= de;
            pixel_x_out <= pixel_x;
            rgb_q       <= rgb_in;
            color_q     <= SUPPORT_MULTI_EMERGENCY ? dynamic_text_color : TEXT_COLOR;
            alarm_q     <= alarm;
            de_q        <= de;
            vs_q        <= vsync;

            if (!vsync)
                line_y <= 12'd0;
            else if (de_q && !de)
                line_y <= line_y + 1'b1;

            if (frame_start) begin
                if (alarm) begin
                    if (fire_scroll_pos >= H_ACT + text_width - SCROLL_STEP)
                        fire_scroll_pos <= 0;
                    else
                        fire_scroll_pos <= fire_scroll_pos + STEP_R;
                end else begin
                    fire_scroll_pos <= H_ACT - (SUPPORT_MULTI_EMERGENCY ? 32 : 16);
                    if (scroll_pos >= SPAN_R - STEP_R)
                        scroll_pos <= 11'd0;
                    else
                        scroll_pos <= scroll_pos + STEP_R;
                end
            end

            // Keep the moving emergency warning out of all four halo edges.
            text_bounds_q <= visible && in_text && (!alarm || (pixel_x >= 28 && pixel_x < 612)) &&
                             (glyph_col < GLYPH_W);
            banner_band_q <= visible && de && (!alarm || (pixel_x >= 24 && pixel_x < 616)) &&
                             (line_y >= band_y - 4) && (line_y < band_y + GLYPH_H_R + 4);
            if (in_text && (glyph_col < GLYPH_W))
                glyph_row_q <= font_row_bits;
            else
                glyph_row_q <= 24'd0;
            glyph_col_q <= glyph_col;
        end
    end

    wire [4:0] safe_glyph_col = (glyph_col_q < GLYPH_W) ? glyph_col_q : 5'd0;
    wire subtitle_hit           = text_bounds_q && displayed_row[23 - safe_glyph_col];
    // Light navy tint: 7/8 source image plus 1/8 banner color. Eleven-bit
    // intermediates preserve highlights without overflow or channel tinting.
    wire [10:0] banner_r_sum = ({3'b0, rgb_q[23:16]} << 3) - {3'b0, rgb_q[23:16]} +
                                 {3'b0, BANNER_COLOR[23:16]};
    wire [10:0] banner_g_sum = ({3'b0, rgb_q[15:8]} << 3) - {3'b0, rgb_q[15:8]} +
                                 {3'b0, BANNER_COLOR[15:8]};
    wire [10:0] banner_b_sum = ({3'b0, rgb_q[7:0]} << 3) - {3'b0, rgb_q[7:0]} +
                                 {3'b0, BANNER_COLOR[7:0]};
    wire [23:0] banner_rgb   = {banner_r_sum[10:3], banner_g_sum[10:3], banner_b_sum[10:3]};
    wire [9:0] emergency_r   = {2'b0, rgb_q[23:16]} + 3 * BANNER_COLOR[23:16];
    wire [9:0] emergency_g   = {2'b0, rgb_q[15:8]} + 3 * BANNER_COLOR[15:8];
    wire [9:0] emergency_b   = {2'b0, rgb_q[7:0]} + 3 * BANNER_COLOR[7:0];
    wire [23:0] readable_banner =
                      (SUPPORT_MULTI_EMERGENCY && alarm_q)
                          ? {emergency_r[9:2], emergency_g[9:2], emergency_b[9:2]}
                          : banner_rgb;
    assign rgb_out         = subtitle_hit ? color_q : (banner_band_q ? readable_banner : rgb_q);
    assign subtitle_active = subtitle_hit;
endmodule
