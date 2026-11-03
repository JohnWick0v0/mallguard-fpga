// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：SW1同步/去抖，在帧边界统一改变普通叠加层可见性。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
module overlay_switch_control #(
    parameter integer DEBOUNCE_CYCLES = 250000
)(
    input wire clk,
               rst_n,
               switch_n,
               vsync,
    output reg hidden
);
    localparam CW = DEBOUNCE_CYCLES > 1 ? $clog2(DEBOUNCE_CYCLES) : 1;
    reg s1, s2, stable_n, vs_q;
    reg [CW - 1:0] count;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            s1       <= 1;
            s2       <= 1;
            stable_n <= 1;
            vs_q     <= 1;
            count    <= 0;
            hidden   <= 0;
        end else begin
            s1   <= switch_n;
            s2   <= s1;
            vs_q <= vsync;
            if (s2 == stable_n)
                count <= 0;
            else if (count == DEBOUNCE_CYCLES - 1) begin
                stable_n <= s2;
                count    <= 0;
            end else
                count <= count + 1'b1;
            if (vs_q && !vsync)
                hidden <= !stable_n;
        end
endmodule
