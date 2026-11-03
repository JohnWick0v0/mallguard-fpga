// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：将毫秒配置转换为面板/OSD秒数，避免显示路径重复大型除法。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Convert a human-timescale value without a 32-bit combinational divider.
// At most 61 clocks are needed for 0..60000 ms. Keep the previous result
// visible until the entire new conversion completes.
module panel_period_counter (
    input wire        clk,
                      rst_n,
                      update_valid,
    input wire [31:0] period_ms,
    output reg [5:0]  seconds
);
    reg [15:0] remaining;
    reg [5:0] count;
    reg busy;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            remaining <= 0;
            count     <= 0;
            busy      <= 0;
            seconds   <= 5;
        end else if (update_valid) begin
            remaining <= period_ms > 60000 ? 16'd60000 : period_ms[15:0];
            count     <= 0;
            busy      <= 1;
        end else if (busy) begin
            if (remaining >= 1000) begin
                remaining <= remaining - 16'd1000;
                count     <= count + 1'b1;
            end else begin
                seconds <= count;
                busy    <= 0;
            end
        end
endmodule
