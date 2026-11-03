// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：协调SW4与串口的广告/视频模式，以及用户暂停状态。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// A physical switch change takes priority over UART; while an emergency is
// locked its sampled state is held so the change is applied after unlock.
// 设计约定：
// 控制优先级：物理SW4变化先于串口指令；应急锁定期间冻结采样状态，解锁后再应用。

module video_mode_control (
    input wire       clk,
                     rst_n,
                     switch_video,
                     locked,
                     remote_allow,
    input wire [3:0] remote_command,
    input wire       key_pause,
    output reg       enabled,
                     paused
);
    reg switch_q;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            enabled  <= 0;
            paused   <= 0;
            switch_q <= 0;
        end else if (!locked) begin
            switch_q <= switch_video;
            if (switch_video != switch_q) begin
                enabled <= switch_video;
                paused  <= 0;
            end else if (remote_allow && (remote_command == 1 || remote_command == 2)) begin
                enabled <= remote_command == 1;
                paused  <= 0;
            end else if (key_pause)
                paused <= ~paused;
            else if (remote_allow && (remote_command == 3 || remote_command == 4))
                paused <= remote_command == 3;
        end
endmodule
