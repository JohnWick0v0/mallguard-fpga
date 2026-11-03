// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：使用请求/确认邮箱传送完整状态快照，源端在确认前保持多位数据。
// 时钟：src_clk、dst_clk。
// 复位：src_rst_n（低有效异步复位）；dst_rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Coalescing mailbox: the source holds the whole bus until a synchronized
// acknowledgement returns. The destination captures after the request has
// passed two FFs; binary percentage bits cannot form a mixed snapshot.
// 产品说明：多位状态不能各自双触发器同步后直接拼接；本模块通过保持数据与请求/确认保证一致性。
// 设计约定：
// 快照约定：发送侧先锁存整束状态并翻转请求，接收侧确认后才允许发送下一份。
// 数据总线在请求至确认期间保持稳定，避免逐位同步产生撕裂的状态快照。

module status_snapshot_cdc #(
    parameter integer WIDTH = 10
)(
    input wire               src_clk,
                             src_rst_n,
    input wire [WIDTH - 1:0] src_value,
    input wire               dst_clk,
                             dst_rst_n,
    output reg [WIDTH - 1:0] dst_value
);
    reg [WIDTH - 1:0] held;
    reg request, acknowledge;
    (* async_reg = "true" *) reg ack_meta, ack_sync, req_meta, req_sync;
    always @(posedge src_clk or negedge src_rst_n)
        if (!src_rst_n) begin
            held     <= 0;
            request  <= 0;
            ack_meta <= 0;
            ack_sync <= 0;
        end else begin
            ack_meta <= acknowledge;
            ack_sync <= ack_meta;
            if (request == ack_sync && held != src_value) begin
                held    <= src_value;
                request <= ~request;
            end
        end
    always @(posedge dst_clk or negedge dst_rst_n)
        if (!dst_rst_n) begin
            req_meta    <= 0;
            req_sync    <= 0;
            acknowledge <= 0;
            dst_value   <= 0;
        end else begin
            req_meta <= request;
            req_sync <= req_meta;
            if (req_sync != acknowledge) begin
                dst_value   <= held;
                acknowledge <= req_sync;
            end
        end
endmodule
