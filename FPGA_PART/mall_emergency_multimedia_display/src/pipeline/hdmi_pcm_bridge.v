// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：把PCM样本转换为HDMI发送核需要的音频节拍与有效握手。
// 时钟：pixel_clk。
// 复位：pixel_rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// Player-owned boundary between the registered video bundle and the verified
// Route B HDMI packet/symbol chain. The EG4 DDR PHY remains in the board Top so
// this bridge can be exercised in ordinary RTL simulation without vendor pads.
// media_id drives the per-image tone selection and volume scales the output,
// turning the tone source into the audio half of the AV-linked feature.
module hdmi_pcm_bridge
    #(parameter integer DVI_ONLY               = 0,
        parameter integer SUPPORT_FIRE         = 0,
        parameter integer SUPPORT_SHARED_ALARM = 0)
    (input wire fire_active, fire_valid,
        input wire fire_use_fallback,
        input wire signed [15:0] fire_sample,
        output wire fire_ready,
        input wire wav_active, wav_valid,
        output wire wav_ready,
        input wire signed [15:0] wav_left, wav_right,
        input wire [7:0] envelope,
        input wire pixel_clk,
        input wire pixel_rst_n,
        input wire video_hsync,
        input wire video_vsync,
        input wire video_de,
        input wire [9:0] video_x,
        input wire [23:0] video_rgb,
        input wire [1:0] media_id,
        input wire [7:0] volume,
        output wire [9:0] clock_symbol,
        output wire [9:0] channel0_symbol,
        output wire [9:0] channel1_symbol,
        output wire [9:0] channel2_symbol,
        output wire sequence_error,
        output wire tone_overflow,
        output wire pcm_contract_error,
        output wire blip_active,
        // PCM tap of the samples actually handed to the packet chain; used by the
        // waveform overlay so the display shows the audio being transmitted.
        output wire pcm_tap_valid,
        output wire signed [15:0] pcm_tap_left);
    wire source_valid;
    wire source_ready;
    wire signed [15:0] source_left;
    wire signed [15:0] source_right;
    wire mux_ready;
    reg wav_selected, held_valid;
    reg signed [15:0] held_left, held_right;
    wire stage_ready                    = !held_valid || mux_ready;
    wire alarm                          = SUPPORT_FIRE && fire_active;
    wire use_shared_alarm               = SUPPORT_SHARED_ALARM && fire_use_fallback;
    wire chosen_valid                   = alarm ? (use_shared_alarm ? source_valid : fire_valid)
                                          : wav_selected ? wav_valid
                                                         : source_valid;
    wire signed [24:0] wav_gain_left  = $signed(wav_left) * $signed({1'b0, volume} + 9'd1);
    wire signed [24:0] wav_gain_right = $signed(wav_right) * $signed({1'b0, volume} + 9'd1);
    wire signed [15:0] mux_left   = wav_selected ? (volume == 0 ? 16'sd0 : wav_gain_left >>> 8)
                                                   : source_left;
    wire signed [15:0] mux_right  = wav_selected ? (volume == 0 ? 16'sd0 : wav_gain_right >>> 8)
                                                   : source_right;
    wire signed [24:0] env_left   = mux_left * $signed({1'b0, envelope} + 9'd1);
    wire signed [24:0] env_right  = mux_right * $signed({1'b0, envelope} + 9'd1);
    wire signed [15:0] gain_left  = envelope == 0 ? 16'sd0 : env_left >>> 8;
    wire signed [15:0] gain_right = envelope == 0 ? 16'sd0 : env_right >>> 8;
    assign wav_ready                = !alarm && wav_selected && stage_ready;
    assign fire_ready               = alarm && !use_shared_alarm && stage_ready;
    assign source_ready             = alarm          ? (use_shared_alarm ? stage_ready : 1'b1)
                                      : wav_selected ? 1'b1
                                                     : stage_ready;
    always @(posedge pixel_clk or negedge pixel_rst_n)
        if (!pixel_rst_n) begin
            wav_selected <= 0;
            held_valid   <= 0;
            held_left    <= 0;
            held_right   <= 0;
        end else if (stage_ready) begin
            wav_selected <= wav_active;
            held_valid   <= chosen_valid;
            if (chosen_valid) begin
                held_left  <= alarm ? (use_shared_alarm ? source_left : fire_sample) : gain_left;
                held_right <= alarm ? (use_shared_alarm ? source_right : fire_sample) : gain_right;
            end
        end
    wire sample_valid;
    wire sample_ready;
    wire signed [15:0] sample_left;
    wire signed [15:0] sample_right;
    assign pcm_tap_valid = sample_valid && sample_ready;
    assign pcm_tap_left  = sample_left;

    background_tone_generator u_tone (
        .clk(pixel_clk),
        .rst_n(pixel_rst_n),
        .media_id(media_id),
        .volume(volume),
        .sample_valid(source_valid),
        .sample_ready(source_ready),
        .sample_left(source_left),
        .sample_right(source_right),
        .overflow(tone_overflow),
        .blip_active(blip_active)
    );

    pcm_stream_adapter u_m06_pcm_contract (
        .clk(pixel_clk),
        .rst_n(pixel_rst_n),
        .source_valid(held_valid),
        .source_ready(mux_ready),
        .source_left(held_left),
        .source_right(held_right),
        .pcm_valid(sample_valid),
        .pcm_ready(sample_ready),
        .pcm_left(sample_left),
        .pcm_right(sample_right),
        .contract_error(pcm_contract_error)
    );

    // Official core consumes a real-time raster with explicit blank intervals.
    // Mark the first active pixel following vertical sync as SOF.
    reg vs_d, frame_pending;
    always @(posedge pixel_clk or negedge pixel_rst_n)
        if (!pixel_rst_n) begin
            vs_d          <= 1;
            frame_pending <= 1;
        end else begin
            vs_d <= video_vsync;
            if (vs_d && !video_vsync)
                frame_pending <= 1;
            else if (video_de)
                frame_pending <= 0;
        end
    wire axis_user = frame_pending && video_de;
    wire axis_last = video_de && video_x == 10'd639;
    wire core_ready, core_locked, ddc_scl;
    tri ddc_sda;
    assign sample_ready   = 1'b1;
    assign sequence_error = 1'b0;
    hdmi_1_4b_transmitter_core_wrapper #(
        .DEVICE("EG"),
        .HTOTAL(800),
        .HSA(96),
        .HFP(16),
        .HBP(48),
        .HACTIVE(640),
        .VTOTAL(525),
        .VSA(2),
        .VFP(10),
        .VBP(33),
        .VACTIVE(480),
        .VIDEO_VIC(1),
        .VIDEO_TPG("Disable"),
        .VIDEO_FORMAT("RGB"),
        .AUDIO_SAMPLE_RATE("48K"),
        .IIC_SCL_DIV(250)
    ) u_official_transmitter (
        .I_pixel_clk(pixel_clk),
        .I_rst(!pixel_rst_n),
        .I_edid_read_trig(1'b0),
        .O_edid_read_valid(),
        .O_edid_read_data(),
        .I_axis_s_user(axis_user),
        .I_axis_s_valid(video_de),
        .I_axis_s_last(axis_last),
        .I_axis_s_data(video_rgb),
        .O_axis_s_ready(core_ready),
        .I_audio_valid(sample_valid),
        .I_audio_left_data({sample_left, 8'd0}),
        .I_audio_right_data({sample_right, 8'd0}),
        .I_acr_valid(1'b1),
        .I_acr_cts(20'd25000),
        .I_acr_n(20'd6144),
        .O_video_locked(core_locked),
        .O_ddc_scl(ddc_scl),
        .IO_ddc_sda(ddc_sda),
        .O_ch0_tmds_data(channel0_symbol),
        .O_ch1_tmds_data(channel1_symbol),
        .O_ch2_tmds_data(channel2_symbol),
        .O_clk_tmds_data(clock_symbol)
    );
endmodule
