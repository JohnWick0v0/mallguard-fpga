// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：协调上电与KEY4/时段切换复位，分别释放系统、存储和像素域。
// 时钟：clk。
// 复位：system_rst_n（向子模块传递，语义见子模块）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// FPGA configuration initializes these registers. KEY1 is now ordinary IO.
// Keep the supervisor on the external 50 MHz clock so it can restart PLLs.
// Soft reset waits for the configuration transaction to finish before
// resetting the Flash SPI owner; it never erases or reconfigures the FPGA.
module system_reset_controller #(
    parameter integer POWER_ON_CYCLES = 500000,
    parameter integer RESET_CYCLES  = 500000
)(
    input wire clk,
    input wire reset_request,
    input wire flash_busy,
    output reg system_rst_n = 1'b0
);
    localparam integer MAX_CYCLES = POWER_ON_CYCLES > RESET_CYCLES ? POWER_ON_CYCLES : RESET_CYCLES;
    localparam integer COUNT_W    = MAX_CYCLES < 2 ? 1 : $clog2(MAX_CYCLES + 1);
    reg [COUNT_W - 1:0] remaining = POWER_ON_CYCLES;
    reg pending                     = 1'b0;
    always @(posedge clk) begin
        if (remaining != 0) begin
            remaining <= remaining - 1'b1;
            pending   <= 0;
            if (remaining == 1)
                system_rst_n <= 1;
        end else begin
            if (reset_request)
                pending <= 1;
            if (pending && !flash_busy) begin
                remaining    <= RESET_CYCLES;
                pending      <= 0;
                system_rst_n <= 0;
            end
        end
    end
endmodule
