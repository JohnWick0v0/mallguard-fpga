// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：64列PCM幅度历史与峰值声浪，依据实际样本更新；属于时域包络而非FFT。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// 64-column PCM amplitude history for the mall display. This is a time-domain
// envelope, not an FFT spectrum. At 48 kHz, 384 samples/bin and 64 bins show
// about 512 ms of recent sound. Display state changes only during VS blanking.
// 产品说明：显示的是时域PCM幅度历史，64条声浪不是64个FFT频段。
module audio_envelope_visualizer #(
    parameter integer SUPPORT_FIRE              = 0,
    parameter integer SUPPORT_MULTI_EMERGENCY = 0,
    parameter integer WAVE_X                  = 184,
    parameter integer WAVE_Y                  = 424,
    parameter integer WAVE_WIDTH              = 256,
    parameter integer WAVE_HEIGHT             = 48,
    parameter integer BIN_SAMPLES             = 384,
    parameter integer PEAK_HOLD_FRAMES        = 12,
    parameter integer PEAK_DECAY_STEP         = 2,
    parameter integer SILENCE_FRAMES          = 2
)(
    input wire               clk,
    input wire               rst_n,
    input wire               vsync,
    input wire               de,
    input wire [23:0]        rgb_in,
    input wire [9:0]         pixel_x,
    input wire               enable,
    input wire               audio_active,
    input wire               fire_active,
    input wire [2:0]         emergency_kind,
    input wire               pcm_tap_valid,
    input wire signed [15:0] pcm_tap_left,
    output wire [23:0]       rgb_out,
    output wire              waveform_active
);
    localparam integer COLUMN_COUNT   = 64;
    localparam integer SAMPLE_SPACING = WAVE_WIDTH / COLUMN_COUNT;
    localparam integer BAR_WIDTH      = SAMPLE_SPACING > 3 ? SAMPLE_SPACING - 2 : 1;
    localparam integer CENTER_Y       = WAVE_Y + WAVE_HEIGHT / 2;
    localparam integer MAX_HEIGHT     = WAVE_HEIGHT / 2 - 7;
    localparam integer METER_HEIGHT   = WAVE_HEIGHT - 16;
    localparam integer METER_BOTTOM   = WAVE_Y + WAVE_HEIGHT - 8;
    localparam integer BIN_BITS       = BIN_SAMPLES > 1 ? $clog2(BIN_SAMPLES) : 1;
    localparam integer HOLD_BITS      = PEAK_HOLD_FRAMES > 0 ? $clog2(PEAK_HOLD_FRAMES + 1) : 1;
    localparam integer SILENCE_BITS   = SILENCE_FRAMES > 0 ? $clog2(SILENCE_FRAMES + 1) : 1;

    reg [11:0] line_y;
    reg de_q, vs_q;
    wire frame_start = vs_q && !vsync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line_y <= 0;
            de_q   <= 0;
            vs_q   <= 1;
        end else begin
            de_q <= de;
            vs_q <= vsync;
            if (!vsync)
                line_y <= 0;
            else if (de_q && !de)
                line_y <= line_y + 1'b1;
        end
    end

    // Unsigned magnitude handles -32768 without signed overflow.
    wire [15:0] pcm_magnitude = pcm_tap_left[15] ? (~pcm_tap_left + 16'd1) : pcm_tap_left;
    wire alarm                  = SUPPORT_FIRE && fire_active;
    reg alarm_q;
    wire mode_changed = alarm != alarm_q;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            alarm_q <= 0;
        else if (frame_start)
            alarm_q <= alarm;
    wire [7:0] raw_level = pcm_magnitude[15] ? 8'hff : pcm_magnitude[14:7];
    // Keep loud siren peaks inside the graph instead of saturating all bars.
    wire [7:0] sample_level = alarm ? {2'b00, raw_level[7:2]} : raw_level;
    reg [7:0] frame_peak;
    wire [7:0] frame_level =
                     pcm_tap_valid && sample_level > frame_peak ? sample_level : frame_peak;
    reg [SILENCE_BITS - 1:0] silent_frames;
    wire quiet_frame   = frame_level == 0 && silent_frames >= SILENCE_FRAMES - 1;
    wire clear_capture = !enable || !audio_active || mode_changed || (frame_start && quiet_frame);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            frame_peak <= 0;
        else if (!enable || !audio_active || mode_changed || frame_start)
            frame_peak <= 0;
        else if (pcm_tap_valid && sample_level > frame_peak)
            frame_peak <= sample_level;
    end

    function [5:0] wave_height;
        input [7:0] amplitude;
        reg [15:0] scaled;
        begin
            scaled      = amplitude * (3 * MAX_HEIGHT);
            wave_height = scaled >= MAX_HEIGHT * 256 ? MAX_HEIGHT : scaled[13:8];
        end
    endfunction
    function [5:0] meter_height;
        input [7:0] amplitude;
        reg [15:0] scaled;
        begin
            scaled       = amplitude * (3 * METER_HEIGHT);
            meter_height = scaled >= METER_HEIGHT * 256 ? METER_HEIGHT : scaled[13:8];
        end
    endfunction

    reg [BIN_BITS - 1:0] bin_count;
    reg [7:0] bin_peak;
    wire [7:0] completed_bin_peak = sample_level > bin_peak ? sample_level : bin_peak;
    reg [7:0] envelope_level;
    wire [8:0] release_step   = ({1'b0, envelope_level} + 9'd15) >> 4;
    wire [7:0] released_level = envelope_level - release_step;
    wire [7:0] completed_envelope =
                     completed_bin_peak >= released_level ? completed_bin_peak : released_level;
    wire [9:0] relative_x   = pixel_x - WAVE_X;
    wire [5:0] column_index = relative_x / SAMPLE_SPACING;
    // A circular capture RAM replaces 64 shift-register columns. Copy the
    // selected history to a second RAM during vertical blanking (128 clocks).
    // Column gaps absorb the synchronous display RAM read latency.
    reg [5:0] write_pointer, snapshot_pointer, copy_index;
    reg [6:0] history_count, snapshot_count;
    reg display_initialized;
    reg copy_busy, copy_phase;
    wire [5:0] history_q, display_q;
`ifndef MALL_RTL_SIMULATION
    // TD会裁剪6位RAM的常量高位并丢失无字节模式下的BE连接。
    // 使用完整8位字节，上两位写0，读取仍取原6位；每块仍占1个BRAM9K。
    // 读口保持原来的单拍时序，字节使能恒为1，不改变写入条件。
    wire [7:0] history_bram_q, display_bram_q;
    assign history_q = history_bram_q[5:0];
    assign display_q = display_bram_q[5:0];
    EG_LOGIC_BRAM #(
        .DATA_WIDTH_A(8), .DATA_WIDTH_B(8),
        .ADDR_WIDTH_A(6), .ADDR_WIDTH_B(6),
        .DATA_DEPTH_A(64), .DATA_DEPTH_B(64),
        .MODE("DP"), .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
        .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"),
        .BYTE_ENABLE(8), .BYTE_A(1), .BYTE_B(1), .IMPLEMENT("9K")
    ) u_history_bram (
        .doa(), .dob(history_bram_q), .dia({2'd0, wave_height(completed_envelope)}), .dib(8'd0),
        .cea(1'b1), .ocea(1'b1), .clka(clk), .wea(!clear_capture && pcm_tap_valid && bin_count == BIN_SAMPLES - 1), .rsta(1'b0),
        .ceb(1'b1), .oceb(1'b1), .clkb(clk), .web(1'b0), .rstb(1'b0),
        .bea(1'b1), .beb(1'b1), .addra(write_pointer), .addrb(((snapshot_pointer + copy_index) & 6'h3f))
    );
    // 显示快照采用相同的整字节配置；仅在copy_phase有效时写入。
    EG_LOGIC_BRAM #(
        .DATA_WIDTH_A(8), .DATA_WIDTH_B(8),
        .ADDR_WIDTH_A(6), .ADDR_WIDTH_B(6),
        .DATA_DEPTH_A(64), .DATA_DEPTH_B(64),
        .MODE("DP"), .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
        .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"),
        .BYTE_ENABLE(8), .BYTE_A(1), .BYTE_B(1), .IMPLEMENT("9K")
    ) u_display_bram (
        .doa(), .dob(display_bram_q), .dia({2'd0, (({1'b0, copy_index} + snapshot_count >= 64) ? history_q : 6'd0)}), .dib(8'd0),
        .cea(1'b1), .ocea(1'b1), .clka(clk), .wea(copy_busy && copy_phase), .rsta(1'b0),
        .ceb(1'b1), .oceb(1'b1), .clkb(clk), .web(1'b0), .rstb(1'b0),
        .bea(1'b1), .beb(1'b1), .addra(copy_index), .addrb(column_index)
    );
`else
    (* ram_style = "bram" *) reg [5:0] history_height[0:63];
    (* ram_style = "bram" *) reg [5:0] display_height[0:63];
    reg [5:0] history_q_sim, display_q_sim;
    assign history_q = history_q_sim;
    assign display_q = display_q_sim;
    always @(posedge clk) begin
        if (!clear_capture && pcm_tap_valid && bin_count == BIN_SAMPLES - 1)
            history_height[write_pointer] <= wave_height(completed_envelope);
        history_q_sim <= history_height[(snapshot_pointer + copy_index) & 6'h3f];
        if (copy_busy && copy_phase)
            display_height[copy_index] <=
                ({1'b0, copy_index} + snapshot_count >= 64) ? history_q : 6'd0;
        display_q_sim <= display_height[column_index];
    end
`endif
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bin_count           <= 0;
            bin_peak            <= 0;
            envelope_level      <= 0;
            write_pointer       <= 0;
            history_count       <= 0;
            snapshot_pointer    <= 0;
            snapshot_count      <= 0;
            copy_index          <= 0;
            copy_busy           <= 0;
            copy_phase          <= 0;
            display_initialized <= 0;
        end else begin
            if (clear_capture) begin
                bin_count      <= 0;
                bin_peak       <= 0;
                envelope_level <= 0;
                write_pointer  <= 0;
                history_count  <= 0;
            end else if (pcm_tap_valid) begin
                if (bin_count == BIN_SAMPLES - 1) begin
                    write_pointer <= write_pointer + 1'b1;
                    if (history_count < 64)
                        history_count <= history_count + 1'b1;
                    envelope_level <= completed_envelope;
                    bin_count      <= 0;
                    bin_peak       <= 0;
                end else begin
                    bin_count <= bin_count + 1'b1;
                    bin_peak  <= completed_bin_peak;
                end
            end
            if (frame_start) begin
                snapshot_pointer <= write_pointer;
                snapshot_count   <= clear_capture ? 7'd0 : history_count;
                copy_index       <= 0;
                copy_busy        <= 1;
                copy_phase       <= 0;
            end else if (copy_busy) begin
                copy_phase <= !copy_phase;
                if (copy_phase) begin
                    if (copy_index == 63) begin
                        copy_busy           <= 0;
                        display_initialized <= 1;
                    end else
                        copy_index <= copy_index + 1'b1;
                end
            end
        end
    end

    reg [7:0] peak_level;
    reg [HOLD_BITS - 1:0] peak_hold;
    reg [5:0] display_meter_height;
    reg [7:0] next_peak;
    always @* begin
        next_peak = peak_level;
        if (frame_level >= peak_level)
            next_peak = frame_level;
        else if (peak_hold == 0) begin
            if (peak_level <= PEAK_DECAY_STEP)
                next_peak = 0;
            else
                next_peak = peak_level - PEAK_DECAY_STEP;
            if (next_peak < frame_level)
                next_peak = frame_level;
        end
    end

    integer display_i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            silent_frames        <= 0;
            peak_level           <= 0;
            peak_hold            <= 0;
            display_meter_height <= 0;

        end else if (frame_start) begin
            if (!enable || !audio_active || mode_changed || quiet_frame) begin
                peak_level           <= 0;
                peak_hold            <= 0;
                display_meter_height <= 0;

            end else begin

                peak_level           <= next_peak;
                display_meter_height <= meter_height(next_peak);
                if (frame_level >= peak_level)
                    peak_hold <= PEAK_HOLD_FRAMES;
                else if (peak_hold != 0)
                    peak_hold <= peak_hold - 1'b1;
            end
            if (!enable || !audio_active || frame_level != 0)
                silent_frames <= 0;
            else if (silent_frames < SILENCE_FRAMES)
                silent_frames <= silent_frames + 1'b1;
        end
    end

    wire [9:0] cell_x = relative_x % SAMPLE_SPACING;
    wire panel_hit = enable && de && pixel_x >= WAVE_X - 8 && pixel_x < WAVE_X + WAVE_WIDTH + 24 &&
                     line_y >= WAVE_Y && line_y < WAVE_Y + WAVE_HEIGHT;
    wire graph_hit = panel_hit && pixel_x >= WAVE_X && pixel_x < WAVE_X + WAVE_WIDTH;
    wire [5:0] height        = display_initialized ? display_q : 6'd0;
    wire bar_hit               = graph_hit && cell_x >= 1 && cell_x <= BAR_WIDTH && height != 0 &&
                                 line_y >= CENTER_Y - height && line_y < CENTER_Y + height;
    wire axis_hit              = graph_hit && line_y == CENTER_Y;
    wire meter_hit             = panel_hit && pixel_x >= WAVE_X + WAVE_WIDTH + 8 &&
                                 pixel_x < WAVE_X + WAVE_WIDTH + 16 && line_y >= WAVE_Y + 8 &&
                                 line_y < METER_BOTTOM;
    wire meter_fill            = meter_hit && line_y >= METER_BOTTOM - display_meter_height;
    wire [7:0] dim_r         = rgb_in[23:16] - {3'b000, rgb_in[23:19]};
    wire [7:0] dim_g         = rgb_in[15:8] - {3'b000, rgb_in[15:11]};
    wire [7:0] dim_b         = rgb_in[7:0] - {3'b000, rgb_in[7:3]};
    wire [23:0] alarm_top    = SUPPORT_MULTI_EMERGENCY && emergency_kind == 3   ? 24'h96c9ff
                                 : SUPPORT_MULTI_EMERGENCY && emergency_kind == 4 ? 24'hfff19c
                                                                                  : 24'hff7b78;
    wire [23:0] alarm_bottom = SUPPORT_MULTI_EMERGENCY && emergency_kind == 3   ? 24'h003388
                                 : SUPPORT_MULTI_EMERGENCY && emergency_kind == 4 ? 24'hffd900
                                                                                  : 24'hff1624;
    wire [23:0] wave_color   = alarm ? (line_y < CENTER_Y ? alarm_top : alarm_bottom)
                                 : line_y < CENTER_Y - WAVE_HEIGHT / 4 ? 24'hb0f8ff
                                 : line_y < CENTER_Y - WAVE_HEIGHT / 8 ? 24'h52e8f4
                                 : line_y < CENTER_Y                   ? 24'h25d9ed
                                 : line_y < CENTER_Y + WAVE_HEIGHT / 8 ? 24'h2aacec
                                 : line_y < CENTER_Y + WAVE_HEIGHT / 4 ? 24'h378fee
                                                                       : 24'h4377ec;
    assign waveform_active     = panel_hit;
    assign rgb_out             = !panel_hit   ? rgb_in
                                 : bar_hit    ? wave_color
                                 : meter_fill ? (alarm ? alarm_bottom : 24'hffca6b)
                                 : meter_hit  ? 24'h243d4c
                                 : axis_hit   ? 24'h406877
                                              : {dim_r, dim_g, dim_b};
endmodule
