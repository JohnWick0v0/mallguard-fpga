// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：整合广告控制、SDRAM像素读取、视频/应急图源选择、亮度与转场。
// 时钟：pix_clk、ctrl_clk、mem_clk、video_clk。
// 复位：pix_rst_n（低有效异步复位）；ctrl_rst_n（向子模块传递，语义见子模块）；mem_rst_n（向子模块传递，语义见子模块）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// 产品说明：图像源切换、亮度和转场需在既有提交时序内完成；RGB与同步/有效/坐标必须同拍。
// 设计约定：
// 合成约定：图片/视频、亮度对比度、OSD、字幕、声浪及通知按既有次序叠加。
// 各级数据有效与同步束必须一起延迟，以免出现横向偏移或画面绕回。

module display_render_pipeline
    #(parameter integer SUPPORT_FIRE              = 0,
        parameter integer SUPPORT_MULTI_EMERGENCY = 0,
        parameter integer IMAGE_WORDS             = 307200,
        parameter integer FIFO_DEPTH              = 512,
        parameter integer H_ACT                   = 640,
        parameter integer H_FP                    = 16,
        parameter integer H_SYNC                  = 96,
        parameter integer H_BP                    = 48,
        parameter integer V_ACT                   = 480,
        parameter integer V_FP                    = 10,
        parameter integer V_SYNC                  = 2,
        parameter integer V_BP                    = 33,
        parameter [31:0] DEFAULT_PERIOD_CYCLES  = 32'd250000000,
        parameter [31:0] MIN_PERIOD_CYCLES      = 32'd50000000,
        parameter [31:0] MAX_PERIOD_CYCLES      = 32'd3000000000,
        // Non-zero enables the fade-out/black/fade-in transition on manual
        // switches and a fade-in on automatic slideshow switches. Zero keeps the
        // legacy direct-switch behaviour for the existing regression suites.
        parameter integer FADE_FRAMES = 0)
    (input wire video_view, video_bank,
        output wire burst_request,
        output wire [7:0] burst_words,
        input wire burst_grant,
        input wire ctrl_clk,
        input wire ctrl_rst_n,
        input wire fire_request, freeze_state, fire_image_ready,
        input wire [2:0] emergency_kind,
        input wire [3:0] emergency_complete,
        output reg fire_active,
        input wire prev_event, select_event, pause_auto,
        input wire [1:0] select_index,
        output wire [7:0] audio_envelope,
        input wire next_event,
        input wire toggle_auto_event,
        input wire period_cfg_valid,
        input wire [31:0] period_cfg_cycles,
        input wire auto_cfg_valid,
        input wire auto_cfg_enabled,
        input wire [3:0] image_complete,
        input wire player_enable,
        input wire thumbnail_view,
        output reg thumbnail_active,

        input wire mem_clk,
        input wire mem_rst_n,
        input wire controller_init_done,
        input wire controller_busy,
        input wire refresh_active,
        output wire app_rd_en,
        output wire [20:0] app_rd_addr,
        input wire sdram_rd_valid,
        input wire [31:0] sdram_rd_data,

        input wire [7:0] brightness,
        input wire pix_clk,
        input wire pix_rst_n,
        output wire video_clk,
        output wire video_hs,
        output wire video_vs,
        output wire video_de,
        output wire [23:0] video_rgb,
        output wire [9:0] video_x,

        output wire [1:0] active_index,
        output wire [1:0] pending_index,
        output wire auto_enabled,
        output wire frame_start,
        output wire reader_busy,
        output wire reader_underflow,
        output wire [7:0] video_error);
    wire raw_hs;
    wire raw_vs;
    wire raw_de;
    wire [11:0] raw_x;
    wire [11:0] raw_y;
    reg raw_vs_q;
    reg [9:0] video_x_q;
    wire index_commit;
    wire [7:0] control_error;
    wire request_busy;
    wire [31:0] active_period_cycles;
    wire [23:0] reader_rgb;
    wire reader_pixel_valid;
    wire reader_done;
    wire [1:0] reader_index;
    wire [7:0] reader_error;
    wire player_enable_pix;
    wire fire_request_pix, fire_ready_pix;
    wire [3:0] emergency_ready_pix;
    genvar ep;
    generate
        for (ep = 0; ep < 4; ep = ep + 1) begin : g_emergency_ready
            sync_2ff u_ready (
                .clk(pix_clk),
                .rst_n(pix_rst_n),
                .async_in(emergency_complete[ep]),
                .sync_out(emergency_ready_pix[ep])
            );
        end
    endgenerate
    wire selected_ready = SUPPORT_MULTI_EMERGENCY ? ((emergency_kind >= 1 && emergency_kind <= 4) &&
                                                        emergency_ready_pix[emergency_kind - 1'b1])
                                                  : fire_ready_pix;
    reg ready_frame;
    always @(posedge pix_clk or negedge pix_rst_n)
        if (!pix_rst_n)
            ready_frame <= 0;
        else if (frame_start)
            ready_frame <= selected_ready;
    sync_2ff u_fire_request_sync (
        .clk(pix_clk),
        .rst_n(pix_rst_n),
        .async_in(SUPPORT_FIRE && fire_request),
        .sync_out(fire_request_pix)
    );
    sync_2ff u_fire_ready_sync (
        .clk(pix_clk),
        .rst_n(pix_rst_n),
        .async_in(SUPPORT_FIRE && fire_image_ready),
        .sync_out(fire_ready_pix)
    );
    always @(posedge pix_clk or negedge pix_rst_n)
        if (!pix_rst_n)
            fire_active <= 0;
        else if (frame_start)
            fire_active <= fire_request_pix;
    reg [7:0] reader_error_pix1;
    reg [7:0] reader_error_pix2;
    reg [7:0] control_error_pix1;
    reg [7:0] control_error_pix2;
    wire [23:0] selected_rgb =
                      fire_active && !(SUPPORT_MULTI_EMERGENCY ? ready_frame : fire_ready_pix)
                          ? 24'h6b0000
                      : (player_enable_pix && reader_pixel_valid && reader_error_pix2 == 0)
                          ? reader_rgb
                          : 24'h000000;

    sync_2ff u_player_enable_pix (
        .clk(pix_clk),
        .rst_n(pix_rst_n),
        .async_in(player_enable),
        .sync_out(player_enable_pix)
    );

    always @(posedge pix_clk or negedge pix_rst_n) begin
        if (!pix_rst_n) begin
            reader_error_pix1  <= 8'd0;
            reader_error_pix2  <= 8'd0;
            control_error_pix1 <= 8'd0;
            control_error_pix2 <= 8'd0;
        end else begin
            reader_error_pix1  <= reader_error;
            reader_error_pix2  <= reader_error_pix1;
            control_error_pix1 <= control_error;
            control_error_pix2 <= control_error_pix1;
        end
    end

    video_timing_ctrl #(
        .H_ACT(H_ACT),
        .H_FP(H_FP),
        .H_SYNC(H_SYNC),
        .H_BP(H_BP),
        .V_ACT(V_ACT),
        .V_FP(V_FP),
        .V_SYNC(V_SYNC),
        .V_BP(V_BP)
    ) u_timing (
        .pclk(pix_clk),
        .rst_n(pix_rst_n),
        .hsync(raw_hs),
        .vsync(raw_vs),
        .de(raw_de),
        .x(raw_x),
        .y(raw_y)
    );

    // Fade transition: manual switch requests are held until the display has
    // faded to black, then released to the control FSM at the frame boundary.
    // The bypass branch (FADE_FRAMES=0) wires next_event straight through so
    // legacy regression timing is unchanged.
    reg [7:0] brightness_frame;
    always @(posedge pix_clk or negedge pix_rst_n)
        if (!pix_rst_n)
            brightness_frame <= 255;
        else if (frame_start)
            brightness_frame <= brightness;
    wire fade_busy;
    wire fade_next_event;
    wire [7:0] fade_alpha;
    wire wipe_active;
    wire [4:0] wipe_ramp;
    assign audio_envelope = (fire_active || video_view) ? 8'd255 : fade_alpha;
    video_fade_transition #(
        .FADE_FRAMES(FADE_FRAMES),
        .SUPPORT_FREEZE(SUPPORT_FIRE)
    ) u_fade (
        .ctrl_clk(ctrl_clk),
        .ctrl_rst_n(ctrl_rst_n),
        .freeze_state(freeze_state),
        .next_event_in(next_event),
        .next_event_out(fade_next_event),
        .fade_busy(fade_busy),
        .pix_clk(pix_clk),
        .pix_rst_n(pix_rst_n),
        .player_active(player_enable_pix),
        .frame_start(frame_start),
        .index_commit(index_commit),
        .alpha_out(fade_alpha),
        .fade_active(),
        .wipe_active(wipe_active),
        .ramp_out(wipe_ramp)
    );

    always @(posedge pix_clk or negedge pix_rst_n) begin
        if (!pix_rst_n)
            raw_vs_q <= 1'b1;
        else
            raw_vs_q <= raw_vs;
    end
    assign frame_start = raw_vs_q && !raw_vs;
    always @(posedge pix_clk or negedge pix_rst_n)
        if (!pix_rst_n)
            thumbnail_active <= 0;
        else if (frame_start)
            thumbnail_active <= thumbnail_view;

    // rgb_video_adapter registers hs/vs/de/rgb by one pixel. Register x in
    // parallel so the HDMI Data Island scheduler sees the coordinate belonging
    // to the same output character, rather than the next raw VTC position.
    always @(posedge pix_clk or negedge pix_rst_n) begin
        if (!pix_rst_n)
            video_x_q <= 10'd0;
        else
            video_x_q <= raw_x[9:0];
    end
    assign video_x = video_x_q;

    advertisement_playback_controller #(
        .SUPPORT_FREEZE(SUPPORT_FIRE),
        .DEFAULT_PERIOD_CYCLES(DEFAULT_PERIOD_CYCLES),
        .MIN_PERIOD_CYCLES(MIN_PERIOD_CYCLES),
        .MAX_PERIOD_CYCLES(MAX_PERIOD_CYCLES)
    ) u_control (
        .prev_event(prev_event),
        .select_event(select_event),
        .select_index(select_index),
        .pause_auto(pause_auto || fade_busy),
        .sys_clk(ctrl_clk),
        .sys_rst_n(ctrl_rst_n),
        .freeze_state(freeze_state),
        .next_event(fade_next_event),
        .toggle_auto_event(toggle_auto_event),
        .period_cfg_valid(period_cfg_valid),
        .period_cfg_cycles(period_cfg_cycles),
        .auto_cfg_valid(auto_cfg_valid),
        .auto_cfg_enabled(auto_cfg_enabled),
        .image_complete(image_complete),
        .auto_enabled(auto_enabled),
        .active_period_cycles(active_period_cycles),
        .pending_index(pending_index),
        .control_error(control_error),
        .request_busy(request_busy),
        .pix_clk(pix_clk),
        .pix_rst_n(pix_rst_n),
        .frame_start(frame_start),
        .active_index(active_index),
        .index_commit(index_commit)
    );

    media_frame_reader #(
        .SUPPORT_DEMO(1),
        .SUPPORT_FIRE(SUPPORT_FIRE),
        .SUPPORT_PACKED16(1),
        .ADDR_WIDTH(21),
        .IMAGE_WORDS(IMAGE_WORDS),
        .FIFO_DEPTH(FIFO_DEPTH),
        .FIFO_MARGIN(4)
    ) u_reader (
        .video_view(video_view),
        .video_bank(video_bank),
        .burst_request(burst_request),
        .burst_words(burst_words),
        .burst_grant(burst_grant),
        .mem_clk(mem_clk),
        .mem_rst_n(mem_rst_n),
        .controller_init_done(controller_init_done && player_enable),
        .controller_busy(controller_busy),
        .refresh_active(refresh_active),
        .app_rd_en(app_rd_en),
        .app_rd_addr(app_rd_addr),
        .sdram_rd_valid(sdram_rd_valid),
        .sdram_rd_data(sdram_rd_data),
        .pix_clk(pix_clk),
        .pix_rst_n(pix_rst_n),
        .frame_start(frame_start && player_enable_pix),
        .active_index(active_index),
        .thumbnail_view(thumbnail_active),
        .fire_view(SUPPORT_MULTI_EMERGENCY ? fire_request_pix && selected_ready : fire_active && fire_ready_pix),
        .emergency_index(emergency_kind[1:0] - 2'd1),
        .pixel_consume(raw_de && player_enable_pix),
        .pixel_rgb(reader_rgb),
        .pixel_valid(reader_pixel_valid),
        .underflow(reader_underflow),
        .reader_busy(reader_busy),
        .frame_read_done(reader_done),
        .reader_index(reader_index),
        .reader_error(reader_error)
    );

    // Fade multiplies the selected frame by the ramp alpha; an automatic
    // slideshow switch instead reveals the new frame left-to-right: pixels
    // right of the moving boundary stay black, the rest show full colour.
    // With FADE_FRAMES=0 the direct assignment keeps every pixel bit-identical
    // to the legacy path so strict regression comparisons still hold.
    wire [23:0] faded_rgb;
    generate
        if (FADE_FRAMES == 0) begin : g_fade_bypass
            // Session brightness applies in the bypass path too. The 9-bit
            // (brightness+1) factor keeps brightness=255 bit-exact (256/256),
            // so legacy regression vectors and the direct-switch behaviour
            // are unchanged at full brightness.
            wire [8:0] eff_bypass = {1'b0, brightness_frame} + 9'd1;
            wire [16:0] bm_r      = {9'd0, selected_rgb[23:16]} * eff_bypass;
            wire [16:0] bm_g      = {9'd0, selected_rgb[15:8]} * eff_bypass;
            wire [16:0] bm_b      = {9'd0, selected_rgb[7:0]} * eff_bypass;
            assign faded_rgb =
                       fire_active ? selected_rgb : {bm_r[15:8], bm_g[15:8], bm_b[15:8]};
        end else begin : g_fade_mul
            // Session-level brightness folds into the transition alpha with
            // one extra 8x8 multiply, so the steady display and the fade both
            // scale together.
            // (brightness+1)/256 keeps full brightness bit-exact (256/256)
            // while lower steps land within 0.4% of brightness/255.
            wire [7:0] visible_alpha = (thumbnail_active || video_view) ? 8'd255 : fade_alpha;
            wire [8:0] af            = {1'b0, visible_alpha} + 9'd1;
            wire [8:0] bf            = {1'b0, brightness_frame} + 9'd1;
            wire [17:0] both_gain    = af * bf;
            wire [8:0] eff_factor    = (visible_alpha == 0 || brightness_frame == 0)
                                             ? 9'd0
                                             : both_gain[16:8];
            wire [16:0] fade_mul_r   = selected_rgb[23:16] * eff_factor;
            wire [16:0] fade_mul_g   = selected_rgb[15:8] * eff_factor;
            wire [16:0] fade_mul_b   = selected_rgb[7:0] * eff_factor;
            wire [23:0] alpha_rgb = {fade_mul_r[15:8], fade_mul_g[15:8], fade_mul_b[15:8]};
            // Reveal boundary advances one H_ACT/FADE_FRAMES column step per
            // frame; the comparison uses the same raw_x that aligns with
            // selected_rgb at this point in the pipeline.
            localparam integer WIPE_STEP = H_ACT / FADE_FRAMES;
            wire [9:0] wipe_boundary   = wipe_ramp * WIPE_STEP;
            // The wipe must reveal the brightness-scaled pixel. Revealing
            // selected_rgb here would briefly force the new image to 100%
            // brightness until the wipe state returns to the alpha path.
            assign faded_rgb = fire_active ? selected_rgb
                               : (wipe_active && !thumbnail_active && !video_view)
                                   ? ((raw_x[9:0] < wipe_boundary) ? alpha_rgb : 24'h000000)
                                   : alpha_rgb;
        end
    endgenerate

    rgb_video_adapter u_video_adapter (
        .pclk(pix_clk),
        .rst_n(pix_rst_n),
        .hs_in(raw_hs),
        .vs_in(raw_vs),
        .de_in(raw_de),
        .rgb_in(faded_rgb),
        .video_clk(video_clk),
        .video_hs(video_hs),
        .video_vs(video_vs),
        .video_de(video_de),
        .video_rgb(video_rgb)
    );

    assign video_error = reader_error_pix2 != 0 ? reader_error_pix2
                         : reader_underflow     ? 8'h63
                                                : control_error_pix2;
endmodule
