// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：在24位RGB画面上叠加状态OSD；保留整束视频信号的流水延迟。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// 24-bit RGB wrapper around the 12-bit status OSD. The overlay core is
// combinational; the downstream watermark stage adds one register delay
// to RGB, DE, X and both syncs. Branding is disabled while preserving this
// complete timing bundle. A local line counter reconstructs pixel_y from the video
// sync/de bundle so the video pipeline needs no extra output port.
// 设计约定：
// 对齐约定：状态OSD与兼容水印级构成完整视频流水，即使水印关闭也保留原有延迟。

module display_status_overlay #(
    parameter integer SUPPORT_FIRE          = 0,
    parameter integer SUPPORT_LIVE_PERIOD = 0,
    parameter integer OSD_X               = 8,
    parameter integer OSD_Y               = 8,
    parameter integer WM_X                = 488,
    parameter integer WM_Y                = 460
)(
    input wire         clk,
    input wire         rst_n,
    input wire         suppress_status,
    input wire         hsync,
    input wire         vsync,
    input wire         de,
    input wire [23:0]  rgb_in,
    input wire [9:0]   pixel_x,
    input wire [1:0]   active_index,
    input wire         auto_enabled,
    input wire [7:0]   error_code,
    input wire [5:0]   period_seconds,
    input wire [1:0]   period_sel,
    input wire [2:0]   volume_sel,
    input wire [1:0]   brightness_sel,
    output wire [23:0] rgb_out,
    output wire        hsync_out,
    output wire        vsync_out,
    output wire        de_out,
    output wire [9:0]  pixel_x_out,
    output wire        osd_active
);
    reg [11:0] line_y;
    reg de_q;
    reg vs_q;
    wire frame_start = vs_q && !vsync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line_y <= 12'd0;
            de_q   <= 1'b0;
            vs_q   <= 1'b1;
        end else begin
            de_q <= de;
            vs_q <= vsync;
            // vsync is active low: hold the line counter at zero through the
            // sync pulse so the first active line after back porch is row 0.
            if (!vsync)
                line_y <= 12'd0;
            else if (de_q && !de)
                line_y <= line_y + 1'b1;
        end
    end

    wire [11:0] osd_rgb12;
    wire osd_hit;

    status_glyph_renderer #(
        .SUPPORT_LIVE_PERIOD(SUPPORT_LIVE_PERIOD),
        .OSD_X(OSD_X),
        .OSD_Y(OSD_Y)
    ) u_osd (
        .clk(clk),
        .rst_n(rst_n),
        .frame_start(frame_start),
        .active_index(active_index),
        .auto_enabled(auto_enabled),
        .error_code(error_code),
        .period_seconds(period_seconds),
        .period_sel(period_sel),
        .volume_sel(volume_sel),
        .brightness_sel(brightness_sel),
        .in_de(de),
        .in_rgb({rgb_in[23:20], rgb_in[15:12], rgb_in[7:4]}),
        .pixel_x({2'b00, pixel_x}),
        .pixel_y(line_y),
        .out_rgb(osd_rgb12),
        .out_de(),
        .osd_pixel(osd_hit)
    );

    // Non-OSD pixels pass the original 24-bit value through untouched;
    // OSD pixels take the 12-bit highlight colour expanded to 24 bits.
    wire [23:0] status_rgb24 = (osd_hit && !(SUPPORT_FIRE && suppress_status))
                                     ? {osd_rgb12[11:8],
                                           osd_rgb12[11:8],
                                           osd_rgb12[7:4],
                                           osd_rgb12[7:4],
                                           osd_rgb12[3:0],
                                           osd_rgb12[3:0]}
                                     : rgb_in;

    wire watermark_hit;
    brand_watermark_24 #(
        .ENABLE(0),
        .WM_X(WM_X),
        .WM_Y(WM_Y)
    ) u_brand_watermark (
        .clk(clk),
        .rst_n(rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .de(de),
        .pixel_x(pixel_x),
        .pixel_y(line_y),
        .rgb_in(status_rgb24),
        .overlay_active_in(osd_hit),
        .hsync_out(hsync_out),
        .vsync_out(vsync_out),
        .de_out(de_out),
        .pixel_x_out(pixel_x_out),
        .rgb_out(rgb_out),
        .overlay_active_out(watermark_hit)
    );
    assign osd_active = watermark_hit;
endmodule
