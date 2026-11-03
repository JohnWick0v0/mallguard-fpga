// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：把真实启动进度快照接入显示域，生成加载/失败提示并同步完成消隐。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Hold only the overlay after real completion; media playback is not delayed.
// The existing loading_banner latches its coherent percentage on the same VS.
module boot_loading_display #(
    parameter integer COMPLETE_FRAMES = 12
)(
    input wire clk,
               rst_n,
               vsync,
               ready,
               failed,
    output reg enable
);
    localparam integer CW = COMPLETE_FRAMES < 2 ? 1 : $clog2(COMPLETE_FRAMES + 1);
    reg vs_q, complete_seen;
    reg [CW - 1:0] remaining;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            vs_q          <= 1;
            complete_seen <= 0;
            remaining     <= 0;
            enable        <= 1;
        end else begin
            vs_q <= vsync;
            if (vs_q && !vsync) begin
                if (!ready || failed) begin
                    complete_seen <= 0;
                    remaining     <= 0;
                    enable        <= 1;
                end else if (!complete_seen) begin
                    complete_seen <= 1;
                    remaining     <= COMPLETE_FRAMES;
                    enable        <= COMPLETE_FRAMES != 0;
                end else if (remaining > 1) begin
                    remaining <= remaining - 1'b1;
                    enable    <= 1;
                end else begin
                    remaining <= 0;
                    enable    <= 0;
                end
            end
        end
endmodule
