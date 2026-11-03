// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：由音频样本推进视频帧提交时刻，支持暂停/恢复及循环。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// 设计约定：
// 音画约定：48kHz音频样本推进播放时基，每4800个样本对应一帧10fps源视频。
// 缺PCM数据时进入buffering并冻结样本时基，恢复水位满足后续播，超时上报D1。
// 视频帧只在vblank且帧索引匹配时提交；提交后返回ack，两个源帧不同步上报D2。

module av_playback_clock #(
    parameter integer CLOCK_HZ = 25000000,
                      SAMPLE_HZ = 48000,
    parameter integer SAMPLES_PER_FRAME = 4800,
                      FRAMES = 160
)(
    input wire                clk,
                              rst_n,
                              armed,
                              play_enable,
                              vblank,
    input wire                pcm_head_valid,
                              pcm_resume_ready,
    input wire [31:0]         pcm_head,
    output wire               pcm_pop,
    output wire               pcm_valid,
    output wire signed [15:0] pcm_sample,
    input wire                ready_toggle,
    input wire [7:0]          ready_index,
    input wire                ready_bank,
    output reg                ack_toggle,
    output reg                active_bank,
    output reg [7:0]          video_index,
    output reg [7:0]          audio_index,
    output reg [7:0]          error,
    output wire               playing,
    output reg [15:0]         loops,
    output reg                buffering
);
    reg [24:0] rate;
    reg [12:0] within_frame;
    reg half;
    reg rt1, rt2, rb1, rb2, seen, pending;
    reg [7:0] ri1, ri2;
    localparam integer STALL_W = $clog2(CLOCK_HZ * 3 + 1);
    reg [STALL_W - 1:0] stall_cycles;
    wire tick         = rate >= CLOCK_HZ - SAMPLE_HZ;
    assign playing    = armed && play_enable && error == 0 && !buffering;
    assign pcm_valid  = playing && tick && pcm_head_valid;
    assign pcm_sample = half ? pcm_head[31:16] : pcm_head[15:0];
    assign pcm_pop    = pcm_valid && half;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rate         <= 0;
            within_frame <= 0;
            half         <= 0;
            rt1          <= 0;
            rt2          <= 0;
            rb1          <= 0;
            rb2          <= 0;
            ri1          <= 0;
            ri2          <= 0;
            seen         <= 0;
            pending      <= 0;
            ack_toggle   <= 0;
            active_bank  <= 0;
            video_index  <= 0;
            audio_index  <= 0;
            error        <= 0;
            loops        <= 0;
            buffering    <= 0;
            stall_cycles <= 0;
        end else begin
            rt1 <= ready_toggle;
            rt2 <= rt1;
            rb1 <= ready_bank;
            rb2 <= rb1;
            ri1 <= ready_index;
            ri2 <= ri1;
            if (rt2 != seen)
                pending <= 1;
            if (buffering) begin
                if (pcm_resume_ready && pcm_head_valid) begin
                    buffering    <= 0;
                    stall_cycles <= 0;
                end else if (play_enable && error == 0) begin
                    if (stall_cycles == CLOCK_HZ * 3 - 1)
                        error <= 8'hd1;
                    else
                        stall_cycles <= stall_cycles + 1'b1;
                end
            end
            if (playing) begin
                if (tick) begin
                    if (pcm_head_valid) begin
                        rate <= rate + SAMPLE_HZ - CLOCK_HZ;
                        half <= ~half;
                        if (within_frame == SAMPLES_PER_FRAME - 1) begin
                            within_frame <= 0;
                            if (audio_index == FRAMES - 1) begin
                                audio_index <= 0;
                                loops       <= loops + 1'b1;
                            end else
                                audio_index <= audio_index + 1'b1;
                        end else
                            within_frame <= within_frame + 1'b1;
                    end else begin
                        buffering    <= 1;
                        stall_cycles <= 0;
                    end
                end else
                    rate <= rate + SAMPLE_HZ;
            end
            if (vblank && pending && ri2 == audio_index && video_index != audio_index) begin
                active_bank <= rb2;
                video_index <= ri2;
                ack_toggle  <= rt2;
                seen        <= rt2;
                pending     <= 0;
            end
            // If two whole source frames elapse without a frame being committed,
            // stop with a visible sync error instead of silently losing AV alignment.
            if (armed && audio_index != video_index &&
                audio_index != (video_index == FRAMES - 1 ? 0 : video_index + 1'b1))
                error <= 8'hd2;
        end
    end
endmodule
