// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：按实际BMP像素与四宫格写入量计数；仅播放器真正就绪时报告100%。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Weighted work progress for the existing cold-boot pipeline. Counters advance
// only on decoded BMP pixels and actual gallery write words. Completion is
// owned by player_ready, so an unfinished SDRAM transaction never claims 100%.
// 设计约定：
// 进度约定：只按真实像素与缩略图写入量累加，播放器就绪后才允许显示100%。

module boot_load_progress #(
    parameter integer SOURCE_PIXELS        = 8 * 640 * 480,
    parameter integer GALLERY_WORDS      = 640 * 480 / 2,
    parameter integer PIXEL_STEP_SHIFT   = 15,
    parameter integer GALLERY_STEP_SHIFT = 13
)(
    input wire       clk,
                     rst_n,
                     memory_ready,
                     card_ready,
                     attempt_start,
    input wire       pixel_valid,
                     gallery_start,
                     gallery_write,
    input wire       final_ingest_failure,
                     gallery_failure,
                     player_ready,
    output reg [7:0] progress,
    output reg       failed
);
    localparam integer PW = $clog2(SOURCE_PIXELS + 1);
    localparam integer GW = $clog2(GALLERY_WORDS + 1);
    reg [PW - 1:0] pixels;
    reg [GW - 1:0] words;
    reg started, gallery;
    wire [7:0] image_percent   = 8'd5 + (pixels >> PIXEL_STEP_SHIFT);
    wire [7:0] gallery_percent = 8'd80 + (words >> GALLERY_STEP_SHIFT);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            pixels  <= 0;
            words   <= 0;
            started <= 0;
            gallery <= 0;
            failed  <= 0;
        end else if (attempt_start) begin
            pixels  <= 0;
            words   <= 0;
            started <= 1;
            gallery <= 0;
            failed  <= 0;
        end else begin
            if (started && !gallery && !failed && pixel_valid && pixels < SOURCE_PIXELS)
                pixels <= pixels + 1'b1;
            if (gallery_start) begin
                gallery <= 1;
                words   <= 0;
            end else if (gallery && !failed && gallery_write && words < GALLERY_WORDS)
                words <= words + 1'b1;
            if (final_ingest_failure || gallery_failure)
                failed <= 1;
        end
    // 产品说明：仅真实像素/写入计数推进百分比；卡顿时保持，ready之前不报告100%。
    always @* begin
        if (player_ready)
            progress = 100;
        else if (gallery)
            progress = gallery_percent > 99 ? 8'd99 : gallery_percent;
        else if (pixels != 0)
            progress = image_percent > 80 ? 8'd80 : image_percent;
        else if (started)
            progress = card_ready ? 8'd4 : 8'd2;
        else
            progress = memory_ready ? 8'd1 : 8'd0;
    end
endmodule
