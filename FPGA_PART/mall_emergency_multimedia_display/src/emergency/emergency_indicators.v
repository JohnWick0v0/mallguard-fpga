// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：应急LED/数码管每秒翻转可见性；火灾/治安/医疗驱动低有效蜂鸣器。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// 设计约定：
// 指示约定：事件码决定数码管内容；LED/数码管的闪烁节拍由本地计数器产生。
// 停电场景仍显示告警信息，但声音是否静音由应急音频路径统一选择。

module emergency_indicators #(
    parameter integer CLOCK_HZ = 50000000
)(
    input wire       clk,
                     rst_n,
                     active,
    input wire [2:0] kind,
    output reg       visible,
    output wire      buzzer_n
);
    localparam CW = $clog2(CLOCK_HZ);
    reg [CW - 1:0] blink_count;
    reg [17:0] tone_count;
    reg tone;
    wire audible = active && (kind == 1 || kind == 3 || kind == 4);
    // Two alternating pitches. The board has a PNP9012 high-side driver:
    // logical high disables it, so the completely quiet level is high.
    wire [17:0] half_period = visible ? CLOCK_HZ / 2000 : CLOCK_HZ / 3600;
    assign buzzer_n           = audible ? !tone : 1'b1;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            blink_count <= 0;
            visible     <= 1;
            tone_count  <= 0;
            tone        <= 0;
        end else begin
            if (!active) begin
                blink_count <= 0;
                visible     <= 1;
            end else if (blink_count == CLOCK_HZ - 1) begin
                blink_count <= 0;
                visible     <= !visible;
            end else
                blink_count <= blink_count + 1'b1;
            if (!audible) begin
                tone_count <= 0;
                tone       <= 0;
            end else if (tone_count >= half_period - 1) begin
                tone_count <= 0;
                tone       <= !tone;
            end else
                tone_count <= tone_count + 1'b1;
        end
endmodule
