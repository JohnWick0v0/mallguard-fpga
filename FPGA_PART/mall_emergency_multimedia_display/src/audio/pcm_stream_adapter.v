// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：按有效/就绪握手适配PCM样本，约束采样交付节奏。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// M06-owned boundary used by the current player project.
// The media-specific source may change its melody, volume or content policy,
// but it must present the frozen PCM valid/ready contract to M07.
module pcm_stream_adapter (
    input wire                clk,
    input wire                rst_n,
    input wire                source_valid,
    output wire               source_ready,
    input wire signed [15:0]  source_left,
    input wire signed [15:0]  source_right,
    output wire               pcm_valid,
    input wire                pcm_ready,
    output wire signed [15:0] pcm_left,
    output wire signed [15:0] pcm_right,
    output reg                contract_error
);
    reg hold_active;
    reg signed [15:0] held_left;
    reg signed [15:0] held_right;

    assign source_ready = pcm_ready;
    assign pcm_valid    = source_valid;
    assign pcm_left     = source_left;
    assign pcm_right    = source_right;

    // A producer must keep both channels stable while valid is asserted and
    // ready is low. This is the M06 contract that M07 consumes.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hold_active    <= 1'b0;
            held_left      <= 16'sd0;
            held_right     <= 16'sd0;
            contract_error <= 1'b0;
        end else if (source_valid && !source_ready) begin
            // Synthesis-friendly strict-inequality form: silicon has no X,
            // and the X-guard value of this check is verification-only.
            if (hold_active && (source_left != held_left || source_right != held_right))
                contract_error <= 1'b1;
            if (!hold_active) begin
                held_left   <= source_left;
                held_right  <= source_right;
                hold_active <= 1'b1;
            end
        end else begin
            hold_active <= 1'b0;
        end
    end
endmodule
