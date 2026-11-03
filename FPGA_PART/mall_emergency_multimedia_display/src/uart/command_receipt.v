// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：生成普通串口命令处理结果回执，区分接收与后续状态生效。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Receipt means accepted/rejected, not that a media reload has completed.
module command_receipt (
    input wire       clk,
                     rst_n,
                     remote_valid,
    input wire [3:0] remote_command,
    input wire       config_ready,
                     busy,
                     video_mode,
                     slot_deferred,
    input wire       start_valid,
                     end_valid,
    input wire [2:0] start_kind,
                     end_kind,
                     current_kind,
    output reg [7:0] receipt_count,
                     command,
                     status
);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            receipt_count <= 0;
            command       <= 0;
            status        <= 0;
        end else if (start_valid || end_valid) begin
            receipt_count <= receipt_count + 1'b1;
            command       <= 8'h20 + {4'd0, (start_valid ? start_kind : end_kind), 1'b0} +
                             (end_valid ? 8'd1 : 8'd0);
            status        <= start_valid ? (current_kind != 0 && current_kind != start_kind ? 1 : 0)
                                         : (current_kind == end_kind ? 0 : 2);
        end else if (remote_valid) begin
            receipt_count <= receipt_count + 1'b1;
            command       <= {4'd0, remote_command};
            if (!config_ready)
                status <= 3;
            else if (remote_command == 12)
                status <= slot_deferred ? 5 : 0;
            else if (busy)
                status <= 1;
            else if (video_mode && (remote_command == 5 || remote_command == 6))
                status <= 2;
            else
                status <= 0;
        end
endmodule
