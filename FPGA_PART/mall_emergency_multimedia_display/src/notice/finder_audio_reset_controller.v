// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：广播状态改变时协调LOST音源重置，避免旧音频残留。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）；stream_reset_n（向子模块传递，语义见子模块）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Drain an already-owned SD sector before resetting the notice player/FIFO.
// Block new requests first, allow two arbiter clocks, then wait for ownership
// release. Restart is keyed to the new upload ID, so each new notice starts
// at the beginning while emergency interruptions merely pause/resume it.
module finder_audio_reset_controller #(
    parameter KEY_WIDTH = 16
)(
    input wire                   clk,
                                 rst_n,
    input wire [KEY_WIDTH - 1:0] notice_id,
    input wire                   sector_busy,
    output wire                  allow_request,
    output wire                  stream_reset_n
);
    reg [KEY_WIDTH - 1:0] previous_id;
    reg [1:0] state;
    reg [3:0] count;
    assign allow_request  = state == 0;
    assign stream_reset_n = rst_n && state != 3;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            previous_id <= 0;
            state       <= 0;
            count       <= 0;
        end else
            case (state)
                0:
                    if (notice_id != previous_id) begin
                        previous_id <= notice_id;
                        state       <= 1;
                        count       <= 2;
                    end
                1:
                    if (count == 0)
                        state <= 2;
                    else
                        count <= count - 1'b1;
                2:
                    if (!sector_busy) begin
                        state <= 3;
                        count <= 8;
                    end
                3:
                    if (count == 0)
                        state <= 0;
                    else
                        count <= count - 1'b1;
            endcase
endmodule
