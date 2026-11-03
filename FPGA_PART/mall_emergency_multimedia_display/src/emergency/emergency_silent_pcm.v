// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：为停电等静音分支提供连续合规的零值PCM节拍。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Continuous timed zero-valued samples actively silence the HDMI sink in
// power-outage mode. Merely stopping valid can leave a previous sample held.
module emergency_silent_pcm #(
    parameter integer CLOCK_HZ = 25000000
)(
    input wire clk,
               rst_n,
               active,
               ready,
    output reg valid
);
    reg [24:0] rate;
    wire tick = rate >= CLOCK_HZ - 48000;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            rate  <= 0;
            valid <= 0;
        end else if (!active) begin
            rate  <= 0;
            valid <= 0;
        end else begin
            rate <= tick ? rate + 48000 - CLOCK_HZ : rate + 48000;
            if (valid && ready)
                valid <= 0;
            if (tick && (!valid || ready))
                valid <= 1;
        end
endmodule
