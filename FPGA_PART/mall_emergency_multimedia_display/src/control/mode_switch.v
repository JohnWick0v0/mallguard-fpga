// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：机械拨码同步与去抖，输出稳定逻辑状态。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
module mode_switch #(
    parameter integer DEBOUNCE = 1000000
)(
    input wire clk,
               rst_n,
               switch_n,
    output reg enabled
);
    reg s1, s2;
    reg [$clog2(DEBOUNCE + 1) - 1:0] count;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            s1      <= 1;
            s2      <= 1;
            count   <= 0;
            enabled <= 0;
        end else begin
            s1 <= switch_n;
            s2 <= s1;
            if (enabled == !s2)
                count <= 0;
            else if (count == DEBOUNCE - 1) begin
                enabled <= !s2;
                count   <= 0;
            end else
                count <= count + 1'b1;
        end
endmodule
