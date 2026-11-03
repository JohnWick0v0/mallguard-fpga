// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：互斥应急会话：当前事件不接受抢占，仅匹配结束指令解除。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Type is established before request assertion. It remains stable through
// frame acknowledgement and exit. Active sessions never accept preemption.
// 产品说明：四类事件互斥：火灾期间doctor不会切到医疗；必须put_out后再接收新事件。
// 设计约定：
// 会话约定：应急事件互斥，仅当前事件匹配的结束命令可以退出；其他事件不抢占。
// 首次进入时保存广告状态，解除时恢复快照，不能把应急强制音量/亮度写回普通设置。

module emergency_session_controller (
    input wire       clk,
                     rst_n,
                     start_valid,
                     end_valid,
    input wire [2:0] start_kind,
                     end_kind,
    input wire       frame_active_sys,
    output reg       requested,
    output reg [2:0] kind
);
    reg [2:0] arm_count;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            requested <= 0;
            kind      <= 0;
            arm_count <= 0;
        end else if (requested || arm_count != 0) begin
            if (end_valid && end_kind == kind) begin
                requested <= 0;
                arm_count <= 0;
            end else if (arm_count != 0) begin
                if (arm_count == 1) begin
                    requested <= 1;
                    arm_count <= 0;
                end else
                    arm_count <= arm_count - 1'b1;
            end
        end else if (!frame_active_sys && start_valid && start_kind >= 1 && start_kind <= 4) begin
            kind      <= start_kind;
            arm_count <= 4;
        end
endmodule
