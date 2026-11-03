// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：商场显示终端产品顶层，连接按键、拨码、串口、存储、音画及声光应急。
// 时钟：mem_clk、sys_clk、pixel_clk。
// 复位：mem_rst_n（低有效异步复位）；ctrl_rst_n（低有效异步复位）；pix_rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
`default_nettype none

// Mall player v8: four context-dependent user keys, automatic power-on
// initialization and KEY4 long-hold software reset; KEY1+KEY2 saves settings.
// 设计约定：
// 系统分域：sys_clk管理按键、串口和配置，mem_clk管理TF/SDRAM，pixel_clk管理显示与音频提交。
// 时段生命周期沿用稳定整链路复位，advertising_slot_supervisor在媒体复位外保留RAM设置。
// 应急会话优先于普通播放与按键重置；解锁条件由匹配的串口结束命令控制。
// 模块、寄存器和实例标识保留，以保持既有top.sdc层级匹配及已验证时序关系。

module mall_guard_display_top #(
    parameter integer HDMI_DVI_ONLY = 0
)(
    input wire        sys_clk,
    input wire        key1_n,
    input wire        key2_n,
    input wire        key3_n,
    input wire        key4_n,
    input wire        uart_rx_i,
    input wire        sw1_n,
    input wire        sw2_n,
                      sw3_n,
                      sw4_n,
    output wire       uart_tx_o,
    output wire       buzzer_n,
    output wire       sd_cs_n,
    output wire       sd_sclk,
    output wire       sd_mosi,
    input wire        sd_miso,
    input wire        flash_miso,
    output wire       flash_cs_n,
    output wire       flash_sclk,
    output wire       flash_mosi,
    output wire       flash_wp_n,
    output wire       flash_hold_n,
    output wire       HDMI_CLK_P,
    output wire       HDMI_D2_P,
    output wire       HDMI_D1_P,
    output wire       HDMI_D0_P,
    output wire [6:0] seg_n,
    output wire [7:0] dig_n,
    output wire [3:0] led
);
    // 模块级信号先声明后使用；位宽、类型和实例层级沿用已验证设计。
    wire pixel_clk;
    wire pix_rst_n;
    wire mem_clk;
    wire mem_rst_n;
    wire frame_start;
    wire video_de;
    wire user_reset_request, config_save_event;
    wire system_rst_n;
    wire video_mode_pix, video_mode_mem;
    wire video_mode_sys, user_pause, switch_video;
    wire clip_loaded, clip_playing, clip_buffering, clip_bank;
    wire [7:0] clip_frame, clip_error;
    wire clip_pcm_valid;
    wire signed [15:0] clip_pcm;
    wire dma_rd_en, dma_wr_en, dma_vreturn, dma_idle, v_burst_req, v_burst_grant;
    wire [7:0] v_burst_count;
    wire [20:0] dma_rd_addr, dma_wr_addr;
    wire [31:0] dma_wr_data;
    wire video_sector_req, video_sector_busy, video_sector_valid, video_sector_done;
    wire [31:0] video_sector_lba;
    wire storage_sector_req, storage_sector_busy, storage_sector_valid, storage_sector_done;
    wire [31:0] storage_sector_lba;
    wire vf_allow, vf_start, vf_valid, vf_done;
    wire [7:0] vf_byte, vf_error;
    wire [31:0] vf_offset;
    wire fs_video_valid;
    wire [31:0] fs_video_cluster, fs_video_size;
    wire fire_requested, fire_frame, fire_frame_sys;
    wire emergency_start, emergency_end;
    wire [2:0] emergency_start_kind, emergency_end_kind, emergency_kind;
    wire [2:0] emergency_kind_pix_sync;
    reg [2:0] emergency_kind_pix;
    wire emergency_visible;
    wire fire_lock;
    wire fire_image_ready;
    wire [3:0] emergency_complete, emergency_complete_pix;
    wire [7:0] fire_image_error;
    wire key_reset_request, key_save_event;
    wire fire_pcm_valid, fire_pcm_ready;
    wire signed [15:0] fire_pcm_sample;
    wire warm_active_mem, warm_loading_mem, warm_hold_mem, warm_stop_mem, warm_clear_mem, warm_storage_reset;
    wire warm_active_sys, warm_loading_sys, warm_hold_pix, warm_loading_pix, warm_cache_sys;
    wire copy_start, copy_done, copy_active, copy_rd_en, copy_wr_en;
    wire [20:0] copy_rd_addr, copy_wr_addr;
    wire [31:0] copy_wr_data;
    wire warm_load_start, warm_gallery_start, warm_done, gallery_transaction, ingest_reserved;
    wire storage_quiescent;
    wire [7:0] warm_error_mem, warm_error_sys, warm_progress_mem, warm_progress_sys;
    wire [7:0] manual_switch_counter, receipt_seq, receipt_cmd, receipt_status;
    wire warm_request_toggle;
    wire storage_rst_n;
    wire storage_clients_rst_n;
    wire normal_audio_mem_rst_n;
    wire normal_audio_pix_rst_n;
    wire warm_active_pix;
    wire frame_mem;
    wire [1:0] copy_index_mem;
    wire copy_gallery_mem;
    reg frame_mem_q;
    reg [3:0] cached_emergency_pages;
    wire [3:0] available_emergency_pages;
    wire config_busy;
    wire [1:0] selected_slot;
    wire slot_reload, slot_restore;
    wire [31:0] slot_period;
    wire [7:0] slot_volume, slot_mode;
    wire [3:0] slot_brightness;
    wire mem_feedback_clk;
    wire mem_clk_shift;
    wire mem_locked;
    wire pixel_clk_5x;
    wire video_locked;
    wire pix_5x_rst_n;
    wire ctrl_rst_n;
    wire rx_byte_valid;
    wire [7:0] rx_byte;
    wire [1:0] notice_requested, notice_kind_sync;
    wire [15:0] notice_id;
    wire notice_uploading, notice_mask_ready;
    wire [3:0] notice_error;
    wire notice_write;
    wire [13:0] notice_address;
    wire [7:0] notice_data;
    wire [1:0] notice_shown;
    wire notice_visible_sys;
    wire sdram_init_done;
    wire sdram_refresh_active;
    wire sdram_busy;
    wire ingest_app_wr_en;
    wire [20:0] ingest_app_wr_addr;
    wire [3:0] ingest_app_wr_mask;
    wire [31:0] ingest_app_wr_data;
    wire player_app_rd_en;
    wire [20:0] player_app_rd_addr;
    wire sdram_rd_valid;
    wire [31:0] sdram_rd_data;
    reg player_enable_mem;
    reg thumbnail_start, thumbnail_started;
    wire thumbnail_busy, thumbnail_done;
    wire [7:0] thumbnail_error;
    wire thumb_rd_en, thumb_wr_en;
    wire [20:0] thumb_rd_addr, thumb_wr_addr;
    wire [3:0] thumb_wr_mask;
    wire [31:0] thumb_wr_data;
    wire ingest_done;
    wire [2:0] ingest_error_stage;
    wire [7:0] ingest_error_code;
    wire [7:0] ingest_error_detail;
    wire [3:0] image_complete;
    reg [1:0] boot_retries;
    reg ingest_start;
    reg ingest_started;
    wire [7:0] fs_spc;
    wire [31:0] fs_fat, fs_data, fs_max, fs_audio_cluster, fs_audio_size;
    wire fs_audio_valid, fs_alarm_valid, fs_lost_valid;
    wire [31:0] fs_lost_cluster, fs_lost_size;
    wire [31:0] fs_alarm_cluster, fs_alarm_size;
    wire tap_valid;
    wire [23:0] tap_rgb;
    wire [15:0] tap_x, tap_y;
    wire [1:0] tap_image;
    wire audio_sector_req, audio_sector_busy, audio_sector_valid, audio_sector_done;
    wire [31:0] audio_sector_lba;
    wire [7:0] audio_sector_byte, audio_sector_error;
    wire [8:0] audio_sector_byte_index;
    wire music_sector_req, music_sector_busy, music_sector_valid, music_sector_done;
    wire [31:0] music_sector_lba;
    wire alarm_sector_req, alarm_sector_busy, alarm_sector_valid, alarm_sector_done;
    wire [31:0] alarm_sector_lba;
    wire alarm_wav_active, alarm_wav_valid, alarm_wav_ready;
    wire signed [15:0] alarm_left, alarm_right;
    wire [7:0] alarm_wav_error;
    wire wav_active, wav_valid, wav_ready;
    wire signed [15:0] wav_left, wav_right;
    wire [7:0] wav_error;
    wire ingest_busy;
    wire card_ready;
    wire card_high_capacity;
    wire [3:0] resource_valid;
    wire storage_error_mem;
    wire [15:0] notice_id_mem;
    wire notice_present_mem, fire_active_mem;
    wire alert_lost;
    wire alert_allow, alert_reset, alert_mem_rst_n, alert_pix_rst_n;
    wire alert_req_raw;
    wire [31:0] alert_lba_raw;
    wire alert_lost_pix, alert_ready_pix;
    wire view_pix, gallery_active_pix;
    wire player_enable_sys;
    wire thumbnail_mode_sys;
    wire [1:0] focus_index_sys;
    wire [1:0] active_index_sys;
    wire next_image_event, prev_image_event, select_image_event;
    wire brightness_event;
    wire config_save_locked;
    wire config_ready;
    wire config_load_done;
    wire config_save_done;
    wire config_apply_valid;
    wire config_rejected;
    wire config_fatal_error;
    wire [7:0] config_error_code;
    wire config_request_dropped;
    wire stored_config_valid;
    wire [31:0] stored_config_version;
    wire [31:0] config_period_ms;
    wire [31:0] config_period_cycles;
    wire [7:0] config_volume;
    wire [7:0] config_mode;
    wire [23:0] config_jedec_id;
    wire [7:0] config_status1, config_status2, config_status3;
    wire auto_enabled;
    wire video_pause_event;
    wire remote_valid;
    wire [3:0] remote_command;
    wire [7:0] remote_value;
    wire remote_allow;
    wire remote_cfg;
    wire [31:0] remote_period;
    wire [7:0] remote_volume;
    wire [7:0] remote_mode;
    wire user_pause_pix;
    wire [3:0] loaded_brightness;
    wire brightness_apply;
    reg [3:0] brightness_level;
    reg [7:0] brightness_sys;
    wire menu_cfg_valid;
    wire [31:0] menu_cfg_period;
    wire [7:0] menu_cfg_volume;
    wire [7:0] menu_cfg_mode;
    wire menu_evt;
    wire [1:0] menu_kind;
    reg fire_deferred_config;
    reg config_save_ok_latched;
    wire [3:0] image_complete_sys;
    wire video_clk;
    wire video_hs;
    wire video_vs;
    wire [23:0] video_rgb;
    wire [9:0] video_x;
    wire [1:0] active_index;
    wire [1:0] pending_index;
    wire reader_busy;
    wire reader_underflow;
    wire [7:0] video_error;
    wire [7:0] brightness_pix;
    wire [7:0] audio_envelope;
    wire [1:0] active_index_video;
    wire [7:0] volume_video;
    wire [9:0] audio_symbol0;
    wire [9:0] audio_symbol1;
    wire [9:0] audio_symbol2;
    wire audio_sequence_error;
    wire audio_tone_overflow;
    wire audio_pcm_contract_error;
    wire audio_phy_phase_error;
    wire audio_blip_active;
    wire storage_error_sys;
    wire video_fault_sys;
    wire audio_fault_sys;
    wire [7:0] video_error_sys;
    wire [7:0] storage_reported_error;
    wire wav_fault_sys;
    wire [7:0] wav_error_sys;
    wire [7:0] reported_error;
    wire auto_enabled_video;
    wire [7:0] reported_error_video;
    reg [1:0] period_sel_sys;
    reg [2:0] volume_sel_sys;
    wire [5:0] panel_seconds;
    wire [5:0] osd_period_seconds;
    wire [1:0] period_sel_video;
    wire [2:0] volume_sel_video;
    wire [1:0] brightness_sel_video;
    wire [7:0] contrast_sys;
    wire [7:0] contrast_pix;
    wire [1:0] focus_pix;
    wire color_hs, color_vs, color_de, thumb_hs, thumb_vs, thumb_de;
    wire [9:0] color_x, thumb_x;
    wire [23:0] color_rgb, thumb_rgb;
    wire overlay_hidden;
    wire hide_normal_overlays;
    wire [23:0] emergency_base_rgb;
    wire [23:0] video_rgb_osd;
    wire video_hs_osd;
    wire video_vs_osd;
    wire video_de_osd;
    wire [9:0] video_x_osd;
    wire [23:0] video_rgb_wave;
    wire audio_pcm_tap_valid;
    wire signed [15:0] audio_pcm_tap_left;
    wire [23:0] video_rgb_sub;
    wire video_hs_sub;
    wire video_vs_sub;
    wire video_de_sub;
    wire [9:0] video_x_sub;
    wire notice_hs, notice_vs, notice_de;
    wire [9:0] notice_x;
    wire [23:0] notice_rgb;
    wire [23:0] video_rgb_final, video_rgb_glow;
    wire [7:0] warm_progress_pix;
    wire warm_failed_pix;
    wire [7:0] boot_progress_mem;
    wire boot_failed_mem, boot_banner_enable;
    wire [9:0] boot_status_mem;
    wire [9:0] boot_status_pix, boot_status_sys;
    wire alarm_error_pix;
    wire notice_audio_select;
    wire normal_feed_ready;
    wire use_alarm_wav;
    wire fallback_valid;
    wire signed [15:0] fallback_sample;
    wire [9:0] official_clock_symbol;
    reg [1:0] active_index_sys_q;
    wire switch_evt;
    wire lost_active_sys;
    wire [3:0] emergency_ready_sys;
    reg [23:0] clip_snapshot, clip_sys1, clip_sys2;
    wire [7:0] seg_bus;

    mode_switch u_video_switch (
        .clk(sys_clk),
        .rst_n(system_rst_n),
        .switch_n(sw4_n),
        .enabled(switch_video)
    );

    // 产品说明：应急锁覆盖普通按键与重置；会话退出由匹配的串口解除命令控制。
    assign fire_lock = fire_requested || fire_frame_sys;

    // Match the field-tested V24 media lifecycle. A slot change reboots the
    // media clients together; the always-on supervisor restores RAM settings.
    // 产品说明：时段切换沿用稳定整链路复位，常开时段监督器在媒体复位外保留RAM参数。
    assign user_reset_request = (key_reset_request && !fire_lock) || slot_reload;

    assign warm_request_toggle = 1'b0;
    assign storage_rst_n       = mem_rst_n && !warm_storage_reset;
    // Do not abandon an in-flight sector. Once it has drained and the cache
    // copy begins, clear queued client ownership until the new group commits.
    assign storage_clients_rst_n  = mem_rst_n && !warm_clear_mem;
    assign normal_audio_mem_rst_n = mem_rst_n && !warm_active_mem;
    assign normal_audio_pix_rst_n = pix_rst_n && !warm_active_pix;

    sync_2ff u_warm_frame (
        .clk(mem_clk),
        .rst_n(mem_rst_n),
        .async_in(frame_start),
        .sync_out(frame_mem)
    );

    always @(posedge mem_clk or negedge mem_rst_n)
        if (!mem_rst_n)
            frame_mem_q <= 0;
        else
            frame_mem_q <= frame_mem;
    sync_2ff u_warm_active_sys (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .async_in(warm_active_mem),
        .sync_out(warm_active_sys)
    );
    sync_2ff u_warm_loading_sys (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .async_in(warm_loading_mem),
        .sync_out(warm_loading_sys)
    );
    sync_2ff u_warm_cache_sys (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .async_in(warm_hold_mem),
        .sync_out(warm_cache_sys)
    );
    sync_2ff u_warm_hold_pix (
        .clk(pixel_clk),
        .rst_n(pix_rst_n),
        .async_in(warm_hold_mem),
        .sync_out(warm_hold_pix)
    );
    sync_2ff u_warm_active_pix (
        .clk(pixel_clk),
        .rst_n(pix_rst_n),
        .async_in(warm_active_mem),
        .sync_out(warm_active_pix)
    );
    sync_2ff u_warm_loading_pix (
        .clk(pixel_clk),
        .rst_n(pix_rst_n),
        .async_in(warm_loading_mem),
        .sync_out(warm_loading_pix)
    );
    sync_2ff u_copy_gallery (
        .clk(mem_clk),
        .rst_n(mem_rst_n),
        .async_in(thumbnail_mode_sys),
        .sync_out(copy_gallery_mem)
    );
    genvar wb;
    generate
        for (wb = 0; wb < 8; wb = wb + 1) begin : g_warm_status
            sync_2ff u_err (
                .clk(sys_clk),
                .rst_n(ctrl_rst_n),
                .async_in(warm_error_mem[wb]),
                .sync_out(warm_error_sys[wb])
            );
            sync_2ff u_prog (
                .clk(sys_clk),
                .rst_n(ctrl_rst_n),
                .async_in(warm_progress_mem[wb]),
                .sync_out(warm_progress_sys[wb])
            );
        end
        for (wb = 0; wb < 2; wb = wb + 1) begin : g_copy_index
            sync_2ff u_sync (
                .clk(mem_clk),
                .rst_n(mem_rst_n),
                .async_in(active_index_sys[wb]),
                .sync_out(copy_index_mem[wb])
            );
        end
    endgenerate

    always @(posedge mem_clk or negedge mem_rst_n)
        if (!mem_rst_n)
            cached_emergency_pages <= 0;
        else
            cached_emergency_pages <= cached_emergency_pages | emergency_complete;
    assign available_emergency_pages =
                     warm_active_mem ? cached_emergency_pages : emergency_complete;
    media_reload_controller u_reload (
        .clk(mem_clk),
        .rst_n(mem_rst_n),
        .request_toggle(warm_request_toggle),
        .front_ready(player_enable_mem),
        .dma_idle(dma_idle),
        .storage_idle(storage_quiescent),
        .controller_idle(!sdram_busy && !sdram_refresh_active),
        .frame_tick(frame_mem && !frame_mem_q),
        .copy_done(copy_done),
        .ingest_done(ingest_done),
        .ingest_ok(ingest_error_stage == 0 && ingest_error_code == 0 && image_complete == 15),
        .gallery_done(thumbnail_done),
        .gallery_ok(thumbnail_error == 0),
        .image_complete(image_complete),
        .active(warm_active_mem),
        .loading(warm_loading_mem),
        .hold_view(warm_hold_mem),
        .stream_stop(warm_stop_mem),
        .stream_clear(warm_clear_mem),
        .storage_reset(warm_storage_reset),
        .copy_start(copy_start),
        .load_start(warm_load_start),
        .gallery_start(warm_gallery_start),
        .done(warm_done),
        .error_code(warm_error_mem),
        .progress(warm_progress_mem)
    );
    frame_hold_copy u_hold_copy (
        .clk(mem_clk),
        .rst_n(mem_rst_n),
        .start(copy_start),
        .admit(dma_idle && !v_burst_req),
        .controller_busy(sdram_busy),
        .refresh(sdram_refresh_active),
        .source_base(copy_gallery_mem ? 21'd614400 : copy_index_mem * 21'd153600),
        .rd_valid(sdram_rd_valid && copy_active),
        .rd_data(sdram_rd_data),
        .busy(),
        .transaction_active(copy_active),
        .done(copy_done),
        .rd_en(copy_rd_en),
        .wr_en(copy_wr_en),
        .rd_addr(copy_rd_addr),
        .wr_addr(copy_wr_addr),
        .wr_data(copy_wr_data)
    );
    assign config_save_event = (key_save_event || (remote_allow && remote_command == 13)) &&
                               !fire_lock && !warm_active_sys;

    system_reset_controller u_system_reset (
        .clk(sys_clk),
        .reset_request(user_reset_request),
        .flash_busy(config_busy),
        .system_rst_n(system_rst_n)
    );

    sys_pll u_mem_pll (
        .refclk(sys_clk),
        .reset(~system_rst_n),
        .clk0_out(mem_feedback_clk),
        .clk1_out(mem_clk),
        .clk2_out(mem_clk_shift),
        .locked(mem_locked)
    );

    video_pll u_video_pll (
        .refclk(sys_clk),
        .reset(~system_rst_n),
        .clk0_out(pixel_clk),
        .clk1_out(pixel_clk_5x),
        .extlock(video_locked)
    );

    reset_sync u_mem_reset (
        .clk(mem_clk),
        .ext_rst_n(system_rst_n & mem_locked),
        .rst_n_sync(mem_rst_n)
    );
    reset_sync u_pix_reset (
        .clk(pixel_clk),
        .ext_rst_n(system_rst_n & video_locked),
        .rst_n_sync(pix_rst_n)
    );
    reset_sync u_pix_5x_reset (
        .clk(pixel_clk_5x),
        .ext_rst_n(system_rst_n & video_locked),
        .rst_n_sync(pix_5x_rst_n)
    );
    reset_sync u_ctrl_reset (
        .clk(sys_clk),
        .ext_rst_n(system_rst_n & video_locked),
        .rst_n_sync(ctrl_rst_n)
    );

    finder_notice_controller u_finder (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .byte_valid(rx_byte_valid),
        .byte_data(rx_byte),
        .emergency_busy(fire_lock),
        .display_visible(notice_visible_sys),
        .requested_kind(notice_requested),
        .notice_id(notice_id),
        .uploading(notice_uploading),
        .mask_ready(notice_mask_ready),
        .error(notice_error),
        .mask_write(notice_write),
        .mask_address(notice_address),
        .mask_data(notice_data)
    );
    sync_2ff u_notice_visible (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .async_in(notice_shown != 0),
        .sync_out(notice_visible_sys)
    );
    genvar nb;
    generate
        for (nb = 0; nb < 2; nb = nb + 1) begin : g_notice_kind
            sync_2ff u_sync (
                .clk(pixel_clk),
                .rst_n(pix_rst_n),
                .async_in(notice_requested[nb]),
                .sync_out(notice_kind_sync[nb])
            );
        end
    endgenerate
    emergency_uart_control u_emergency_uart (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .uart_rx(uart_rx_i),
        .rx_byte_valid(rx_byte_valid),
        .rx_byte(rx_byte),
        .fire_event(),
        .put_out_event(),
        .start_valid(emergency_start),
        .end_valid(emergency_end),
        .start_kind(emergency_start_kind),
        .end_kind(emergency_end_kind),
        .framing_error()
    );
    sync_2ff u_fire_frame_ack (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .async_in(fire_frame),
        .sync_out(fire_frame_sys)
    );

    sdram u_sdram (
        .Clk(mem_clk),
        .Clk_sft(mem_clk_shift),
        .Rst(~mem_rst_n),
        .Sdr_init_done(sdram_init_done),
        .Sdr_init_ref_vld(sdram_refresh_active),
        .Sdr_busy(sdram_busy),
        .App_wr_en(copy_wr_en || ((warm_clear_mem || !player_enable_mem) ? (thumbnail_busy ? thumb_wr_en : ingest_app_wr_en) : dma_wr_en)),
        .App_wr_addr(copy_wr_en ? copy_wr_addr : (warm_clear_mem || !player_enable_mem) ? (thumbnail_busy ? thumb_wr_addr : ingest_app_wr_addr) : dma_wr_addr),
        .App_wr_dm(4'd0),
        .App_wr_din(copy_wr_en ? copy_wr_data : (warm_clear_mem || !player_enable_mem) ? (thumbnail_busy ? thumb_wr_data : ingest_app_wr_data) : dma_wr_data),
        .App_rd_en(copy_rd_en || (gallery_transaction    ? thumb_rd_en : player_enable_mem ? dma_rd_en : thumb_rd_en)),
        .App_rd_addr(copy_active           ? copy_rd_addr : gallery_transaction ? thumb_rd_addr : player_enable_mem   ? dma_rd_addr : thumb_rd_addr),
        .Sdr_rd_en(sdram_rd_valid),
        .Sdr_rd_dout(sdram_rd_data)
    );

    always @(posedge mem_clk or negedge mem_rst_n) begin
        if (!mem_rst_n) begin
            boot_retries   <= 0;
            ingest_start   <= 1'b0;
            ingest_started <= 1'b0;
        end else begin
            ingest_start <= 1'b0;
            if (warm_load_start) begin
                ingest_start   <= 1;
                ingest_started <= 1;
                boot_retries   <= 0;
            end
            if (ingest_done &&
                (ingest_error_stage != 0 || ingest_error_code != 0 || image_complete != 4'hf) &&
                boot_retries < 1 && !warm_active_mem) begin
                ingest_started <= 0;
                boot_retries   <= boot_retries + 1'b1;
            end
            if (sdram_init_done && !ingest_started) begin
                ingest_start   <= 1'b1;
                ingest_started <= 1'b1;
            end
        end
    end

    tf_storage_pipeline #(
        .SPI_CLK_DIV(1),
        .SUPPORT_SLOTS(1),
        .LOAD_FIRE(1),
        .LOAD_MULTI_EMERGENCY(1),
        .SUPPORT_QUIESCE(1)
    ) u_storage_ingest (
        .quiesce(warm_stop_mem),
        .quiescent(storage_quiescent),
        .vf_allow(vf_allow),
        .vf_owner(player_enable_mem && !warm_active_mem),
        .vf_start(vf_start),
        .vf_cluster(fs_video_cluster),
        .vf_size(fs_video_size),
        .vf_valid(vf_valid),
        .vf_done(vf_done),
        .vf_byte(vf_byte),
        .vf_error(vf_error),
        .vf_offset(vf_offset),
        .vf_req(video_sector_req),
        .vf_lba(video_sector_lba),
        .vf_busy(video_sector_busy),
        .vf_sector_valid(video_sector_valid),
        .vf_sector_done(video_sector_done),
        .vf_sector_byte(audio_sector_byte),
        .vf_sector_index(audio_sector_byte_index),
        .vf_sector_error(audio_sector_error),
        .selected_slot(selected_slot),
        .emergency_complete(emergency_complete),
        .fire_complete(fire_image_ready),
        .fire_error(fire_image_error),
        .fs_spc(fs_spc),
        .fs_fat(fs_fat),
        .fs_data(fs_data),
        .fs_max(fs_max),
        .fs_lost_valid(fs_lost_valid),
        .fs_lost_cluster(fs_lost_cluster),
        .fs_lost_size(fs_lost_size),
        .fs_alarm_valid(fs_alarm_valid),
        .fs_alarm_cluster(fs_alarm_cluster),
        .fs_alarm_size(fs_alarm_size),
        .fs_video_valid(fs_video_valid),
        .fs_video_cluster(fs_video_cluster),
        .fs_video_size(fs_video_size),
        .fs_audio_valid(fs_audio_valid),
        .fs_audio_cluster(fs_audio_cluster),
        .fs_audio_size(fs_audio_size),
        .tap_valid(tap_valid),
        .tap_rgb(tap_rgb),
        .tap_x(tap_x),
        .tap_y(tap_y),
        .tap_image(tap_image),
        .audio_sector_req(storage_sector_req && !warm_active_mem),
        .audio_sector_lba(storage_sector_lba),
        .audio_sector_busy(storage_sector_busy),
        .audio_sector_valid(storage_sector_valid),
        .audio_sector_done(storage_sector_done),
        .audio_sector_byte(audio_sector_byte),
        .audio_sector_error(audio_sector_error),
        .audio_sector_byte_index(audio_sector_byte_index),
        .clk(mem_clk),
        .rst_n(storage_rst_n),
        .start(ingest_start),
        .busy(ingest_busy),
        .done(ingest_done),
        .error_stage(ingest_error_stage),
        .error_code(ingest_error_code),
        .error_detail(ingest_error_detail),
        .card_ready(card_ready),
        .card_high_capacity(card_high_capacity),
        .resource_valid(resource_valid),
        .image_complete(image_complete),
        .controller_init_done(sdram_init_done),
        .controller_busy(sdram_busy || (warm_active_mem && (!dma_idle || v_burst_req))),
        .refresh_active(sdram_refresh_active),
        .write_reserved(ingest_reserved),
        .app_wr_en(ingest_app_wr_en),
        .app_wr_addr(ingest_app_wr_addr),
        .app_wr_mask(ingest_app_wr_mask),
        .app_wr_data(ingest_app_wr_data),
        .sd_cs_n(sd_cs_n),
        .sd_sclk(sd_sclk),
        .sd_mosi(sd_mosi),
        .sd_miso(sd_miso)
    );

    audio_sector_arbiter u_video_sd_arbiter (
        .clk(mem_clk),
        .rst_n(storage_clients_rst_n),
        .a_req(audio_sector_req),
        .a_lba(audio_sector_lba),
        .a_busy(audio_sector_busy),
        .a_valid(audio_sector_valid),
        .a_done(audio_sector_done),
        .b_req(video_sector_req),
        .b_lba(video_sector_lba),
        .b_busy(video_sector_busy),
        .b_valid(video_sector_valid),
        .b_done(video_sector_done),
        .sector_req(storage_sector_req),
        .sector_lba(storage_sector_lba),
        .sector_busy(storage_sector_busy),
        .sector_valid(storage_sector_valid),
        .sector_done(storage_sector_done)
    );
    video_playback_pipeline #(
        .SUPPORT_MAINTENANCE(1)
    ) u_clip (
        .maintenance(warm_stop_mem),
        .clear_stream(warm_clear_mem),
        .mem_clk(mem_clk),
        .mem_rst_n(mem_rst_n),
        .pix_clk(pixel_clk),
        .pix_rst_n(pix_rst_n),
        .controller_ready(sdram_init_done && player_enable_mem),
        .controller_busy(sdram_busy || copy_active || gallery_transaction || (warm_active_mem && ingest_reserved)),
        .refresh(sdram_refresh_active),
        .app_rd_en(dma_rd_en),
        .app_rd_addr(dma_rd_addr),
        .app_wr_en(dma_wr_en),
        .app_wr_addr(dma_wr_addr),
        .app_wr_data(dma_wr_data),
        .rd_valid(sdram_rd_valid && player_enable_mem && !copy_active && !gallery_transaction),
        .rd_data(sdram_rd_data),
        .vblank(frame_start),
        .active_pixel(video_de),
        .v_req(v_burst_req),
        .v_count(v_burst_count),
        .v_grant(v_burst_grant),
        .v_en(player_app_rd_en),
        .v_addr(player_app_rd_addr),
        .vr(dma_vreturn),
        .dma_idle(dma_idle),
        .active_bank(clip_bank),
        .play_enable(video_mode_pix && !user_pause_pix && !fire_frame && notice_kind_sync == 0),
        .pcm_valid(clip_pcm_valid),
        .pcm_sample(clip_pcm),
        .loaded(clip_loaded),
        .playing(clip_playing),
        .buffering(clip_buffering),
        .frame_number(clip_frame),
        .error_code(clip_error),
        .vf_allow(vf_allow),
        .vf_start(vf_start),
        .vf_valid(vf_valid),
        .vf_done(vf_done),
        .vf_byte(vf_byte),
        .vf_error(vf_error),
        .vf_offset(vf_offset),
        .directory_ready(player_enable_mem),
        .directory_valid(fs_video_valid),
        .directory_cluster(fs_video_cluster),
        .directory_size(fs_video_size),
        .directory_spc(fs_spc),
        .directory_fat(fs_fat),
        .directory_data(fs_data),
        .directory_max(fs_max),
        .sector_req(),
        .sector_lba(),
        .sector_busy(video_sector_busy),
        .sector_valid(video_sector_valid),
        .sector_done(video_sector_done),
        .sector_byte(audio_sector_byte),
        .sector_byte_index(audio_sector_byte_index),
        .sector_error(audio_sector_error)
    );
    // Ownership: load original frames -> build native full-color gallery ->
    // playback. Gallery building never competes with live HDMI reads.
    packed_gallery_builder #(
        .SUPPORT_ARBITRATION(1)
    ) u_thumbnail_builder (
        .pause_admission(player_enable_mem && (!dma_idle || v_burst_req)),
        .transaction_active(gallery_transaction),
        .clk(mem_clk),
        .rst_n(mem_rst_n),
        .start(thumbnail_start),
        .controller_init_done(sdram_init_done),
        .controller_busy(sdram_busy),
        .refresh_active(sdram_refresh_active),
        .busy(thumbnail_busy),
        .done(thumbnail_done),
        .error_code(thumbnail_error),
        .app_rd_en(thumb_rd_en),
        .app_rd_addr(thumb_rd_addr),
        .sdram_rd_valid(sdram_rd_valid && (!player_enable_mem || gallery_transaction)),
        .sdram_rd_data(sdram_rd_data),
        .app_wr_en(thumb_wr_en),
        .app_wr_addr(thumb_wr_addr),
        .app_wr_mask(thumb_wr_mask),
        .app_wr_data(thumb_wr_data)
    );

    always @(posedge mem_clk or negedge mem_rst_n) begin
        if (!mem_rst_n) begin
            player_enable_mem <= 1'b0;
            thumbnail_start   <= 0;
            thumbnail_started <= 0;
        end else begin
            thumbnail_start <= 0;
            if (warm_gallery_start)
                thumbnail_start <= 1;
            if (ingest_done && ingest_error_stage == 0 && ingest_error_code == 0 &&
                image_complete == 4'hf && !thumbnail_started) begin
                thumbnail_start   <= 1;
                thumbnail_started <= 1;
            end
            if (thumbnail_done && thumbnail_error == 0)
                player_enable_mem <= 1;
        end
    end

    assign alert_lost = notice_present_mem && !fire_active_mem;

    generate
        for (nb = 0; nb < 16; nb = nb + 1) begin : g_notice_id
            sync_2ff u_sync (
                .clk(mem_clk),
                .rst_n(mem_rst_n),
                .async_in(notice_id[nb]),
                .sync_out(notice_id_mem[nb])
            );
        end
    endgenerate
    sync_2ff u_alert_notice (
        .clk(mem_clk),
        .rst_n(mem_rst_n),
        .async_in(notice_requested != 0),
        .sync_out(notice_present_mem)
    );
    sync_2ff u_alert_fire (
        .clk(mem_clk),
        .rst_n(mem_rst_n),
        .async_in(fire_frame),
        .sync_out(fire_active_mem)
    );
    finder_audio_reset_controller #(
        .KEY_WIDTH(18)
    ) u_alert_restart (
        .clk(mem_clk),
        .rst_n(storage_clients_rst_n),
        .notice_id({fire_active_mem, notice_present_mem, notice_id_mem}),
        .sector_busy(alarm_sector_busy),
        .allow_request(alert_allow),
        .stream_reset_n(alert_reset)
    );
    reset_sync u_alert_mem_reset (
        .clk(mem_clk),
        .ext_rst_n(alert_reset),
        .rst_n_sync(alert_mem_rst_n)
    );
    reset_sync u_alert_pix_reset (
        .clk(pixel_clk),
        .ext_rst_n(alert_reset && pix_rst_n),
        .rst_n_sync(alert_pix_rst_n)
    );

    sync_2ff u_alert_ready (
        .clk(pixel_clk),
        .rst_n(pix_rst_n),
        .async_in(alert_allow),
        .sync_out(alert_ready_pix)
    );
    sync_2ff u_alert_mode (
        .clk(pixel_clk),
        .rst_n(pix_rst_n),
        .async_in(alert_lost && alert_allow),
        .sync_out(alert_lost_pix)
    );
    assign alarm_sector_req = alert_req_raw && alert_allow;
    assign alarm_sector_lba = alert_lba_raw;
    wav_file_player #(
        .USE_EXTERNAL_DIRECTORY(1),
        .SUPPORT_PAUSE(1),
        .FIFO_AW(10),
        .MONO_ONLY(1),
        .COMPACT_LOOP_CHECK(1)
    ) u_wav (
        .pause_playback(fire_frame || video_mode_pix || notice_kind_sync != 0),
        .directory_valid(fs_audio_valid),
        .directory_spc(fs_spc),
        .directory_fat(fs_fat),
        .directory_data(fs_data),
        .directory_max(fs_max),
        .directory_cluster(fs_audio_cluster),
        .directory_size(fs_audio_size),
        .mem_clk(mem_clk),
        .mem_rst_n(normal_audio_mem_rst_n),
        .enable(player_enable_mem),
        .sector_req(music_sector_req),
        .sector_lba(music_sector_lba),
        .sector_busy(music_sector_busy),
        .sector_valid(music_sector_valid),
        .sector_done(music_sector_done),
        .sector_byte(audio_sector_byte),
        .sector_error(audio_sector_error),
        .sector_byte_index(audio_sector_byte_index),
        .pix_clk(pixel_clk),
        .pix_rst_n(normal_audio_pix_rst_n),
        .active(wav_active),
        .sample_valid(wav_valid),
        .sample_ready(wav_ready),
        .sample_left(wav_left),
        .sample_right(wav_right),
        .error_code(wav_error)
    );
    // Independent FIFO/read pointer preserves the paused advertisement music.
    // Requests are queued and arbitrated per complete SD sector, including FAT.
    audio_sector_arbiter u_audio_sd_arbiter (
        .clk(mem_clk),
        .rst_n(storage_clients_rst_n),
        .a_req(music_sector_req),
        .a_lba(music_sector_lba),
        .a_busy(music_sector_busy),
        .a_valid(music_sector_valid),
        .a_done(music_sector_done),
        .b_req(alarm_sector_req),
        .b_lba(alarm_sector_lba),
        .b_busy(alarm_sector_busy),
        .b_valid(alarm_sector_valid),
        .b_done(alarm_sector_done),
        .sector_req(audio_sector_req),
        .sector_lba(audio_sector_lba),
        .sector_busy(audio_sector_busy),
        .sector_valid(audio_sector_valid),
        .sector_done(audio_sector_done)
    );
    wav_file_player #(
        .USE_EXTERNAL_DIRECTORY(1),
        .SUPPORT_PAUSE(1),
        .FIFO_AW(10),
        .MONO_ONLY(1),
        .COMPACT_LOOP_CHECK(1)
    ) u_alarm_wav (
        .pause_playback(alert_lost_pix ? notice_kind_sync == 0 || fire_frame : !fire_frame || emergency_kind_pix == 2),
        .directory_valid(alert_lost ? fs_lost_valid : fs_alarm_valid),
        .directory_spc(fs_spc),
        .directory_fat(fs_fat),
        .directory_data(fs_data),
        .directory_max(fs_max),
        .directory_cluster(alert_lost ? fs_lost_cluster : fs_alarm_cluster),
        .directory_size(alert_lost ? fs_lost_size : fs_alarm_size),
        .mem_clk(mem_clk),
        .mem_rst_n(alert_mem_rst_n),
        .enable(player_enable_mem),
        .sector_req(alert_req_raw),
        .sector_lba(alert_lba_raw),
        .sector_busy(alarm_sector_busy || !alert_allow),
        .sector_valid(alarm_sector_valid),
        .sector_done(alarm_sector_done),
        .sector_byte(audio_sector_byte),
        .sector_error(audio_sector_error),
        .sector_byte_index(audio_sector_byte_index),
        .pix_clk(pixel_clk),
        .pix_rst_n(alert_pix_rst_n),
        .active(alarm_wav_active),
        .sample_valid(alarm_wav_valid),
        .sample_ready(alarm_wav_ready),
        .sample_left(alarm_left),
        .sample_right(alarm_right),
        .error_code(alarm_wav_error)
    );

    display_command_decoder u_remote (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .byte_valid(rx_byte_valid),
        .byte_data(rx_byte),
        .valid(remote_valid),
        .command(remote_command),
        .value(remote_value)
    );
    assign remote_allow =
             remote_valid && config_ready && !fire_lock && !notice_uploading && !warm_active_sys;
    assign remote_cfg             = remote_allow && (remote_command == 7 || remote_command == 8 ||
                                                      remote_command == 9 || remote_command == 11);
    assign remote_period = remote_command == 11 ? remote_value * 32'd1000 : config_period_ms;

    assign remote_volume = remote_command == 9 ? (remote_value == 0       ? 8'd0
                                                           : remote_value == 25 ? 8'd64
                                                           : remote_value == 50 ? 8'd128
                                                           : remote_value == 75 ? 8'd192
                                                                                : 8'd255)
                                                     : config_volume;
    assign remote_mode   = remote_command == 7   ? 8'd1
                                 : remote_command == 8 ? 8'd0
                                                       : config_mode;
    video_mode_control u_video_mode (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .switch_video(switch_video),
        .locked(fire_lock || warm_active_sys),
        .remote_allow(remote_allow),
        .remote_command(remote_command),
        .key_pause(video_pause_event),
        .enabled(video_mode_sys),
        .paused(user_pause)
    );

    sync_2ff u_pause_pix (
        .clk(pixel_clk),
        .rst_n(pix_rst_n),
        .async_in(user_pause),
        .sync_out(user_pause_pix)
    );
    sync_2ff u_vm_pix (
        .clk(pixel_clk),
        .rst_n(pix_rst_n),
        .async_in(video_mode_sys),
        .sync_out(video_mode_pix)
    );
    sync_2ff u_vm_mem (
        .clk(mem_clk),
        .rst_n(mem_rst_n),
        .async_in(video_mode_sys),
        .sync_out(video_mode_mem)
    );

    // Brightness and contrast share four bits in the compatible tagged record.

    // 产品说明：低2位是100/75/50/25%亮度，高2位是对比度。KEY4共16种组合；light命令回到常规对比度。

    always @(posedge sys_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n)
            brightness_level <= 4'd0;
        else if (brightness_apply)
            brightness_level <= loaded_brightness;
        else if (slot_restore)
            brightness_level <= slot_brightness;
        else if (remote_allow && remote_command == 10)
            brightness_level <= (remote_value >= 88   ? 0
                                 : remote_value >= 63 ? 1
                                 : remote_value >= 38 ? 2
                                                      : 3);
        else if (brightness_event && !fire_lock)
            brightness_level <= brightness_level + 1'b1;
    end

    always @* begin
        case (brightness_level[1:0])
            2'd0:
                brightness_sys = 8'd255;
            2'd1:
                brightness_sys = 8'd192;
            2'd2:
                brightness_sys = 8'd128;
            default:
                brightness_sys = 8'd64;
        endcase
    end

    emergency_session_controller u_emergency_session (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .start_valid(emergency_start),
        .end_valid(emergency_end),
        .start_kind(emergency_start_kind),
        .end_kind(emergency_end_kind),
        .frame_active_sys(fire_frame_sys),
        .requested(fire_requested),
        .kind(emergency_kind)
    );
    // A boot-time configuration load may finish while the alarm is active.
    // Replay that apply pulse after unlock rather than losing its A/E mode.

    always @(posedge sys_clk or negedge ctrl_rst_n)
        if (!ctrl_rst_n)
            fire_deferred_config <= 0;
        else if (!(fire_lock || video_mode_sys))
            fire_deferred_config <= 0;
        else if (config_apply_valid)
            fire_deferred_config <= 1;

    display_key_controller #(
        .SUPPORT_INHIBIT(1)
    ) u_keys (
        .video_mode(video_mode_sys),
        .video_pause_event(video_pause_event),
        .inhibit(fire_lock || warm_active_sys),
        .clk(sys_clk),
        .rst_n(system_rst_n),
        .keys_n({key4_n, key3_n, key2_n, key1_n}),
        .service_ready(config_ready && !fire_lock),
        .player_ready(player_enable_sys && !fire_lock),
        .active_index(active_index_sys),
        .live_volume(config_volume),
        .live_period_ms(config_period_ms),
        .auto_enabled(config_mode[0]),
        .thumbnail_mode(thumbnail_mode_sys),
        .focus_index(focus_index_sys),
        .next_event(next_image_event),
        .prev_event(prev_image_event),
        .select_event(select_image_event),
        .brightness_event(brightness_event),
        .reset_request(key_reset_request),
        .save_event(key_save_event),
        .save_locked(config_save_locked),
        .cfg_valid(menu_cfg_valid),
        .cfg_period_ms(menu_cfg_period),
        .cfg_volume(menu_cfg_volume),
        .cfg_mode(menu_cfg_mode),
        .menu_event(menu_evt),
        .menu_kind(menu_kind)
    );

    advertising_slot_supervisor #(
        .SUPPORT_WARM(0)
    ) u_timeslot (
        .remote_slot_valid(remote_valid && remote_command == 12 && config_ready),
        .remote_slot(remote_value[1:0]),
        .load_busy(warm_loading_sys),
        .manual_counter(manual_switch_counter),
        .clk(sys_clk),
        .sw2_n(sw2_n),
        .sw3_n(sw3_n),
        .system_running(system_rst_n),
        .control_running(ctrl_rst_n),
        .allow_change(player_enable_sys && !warm_loading_sys && !video_mode_sys && !fire_lock && notice_requested == 0 && !notice_uploading && !config_busy),
        .config_ready(config_ready),
        .live_period_ms(config_period_ms),
        .live_volume(config_volume),
        .live_mode(config_mode),
        .live_brightness(brightness_level),
        .selected_slot(selected_slot),
        .reload_request(slot_reload),
        .restore_valid(slot_restore),
        .saved_period_ms(slot_period),
        .saved_volume(slot_volume),
        .saved_mode(slot_mode),
        .saved_brightness(slot_brightness)
    );

    display_settings_store #(.SUPPORT_BRIGHTNESS(1))
        u_player_config(.live_brightness(brightness_level),
            .loaded_brightness(loaded_brightness),
            .brightness_apply(brightness_apply),
            .clk(sys_clk),
            .rst_n(ctrl_rst_n),
            .cfg_update_valid(
                slot_restore || remote_cfg || (menu_cfg_valid && config_ready && !fire_lock)),
            .cfg_period_ms(slot_restore ? slot_period
                           : remote_cfg ? remote_period
                                        : menu_cfg_period),
            .cfg_volume(slot_restore ? slot_volume
                        : remote_cfg ? remote_volume
                                     : menu_cfg_volume),
            // A/E uses the same live-config apply path as volume and period;
            // there is no second toggle that could invert the mode twice.
            .cfg_mode(slot_restore ? slot_mode
                      : remote_cfg ? remote_mode
                                   : menu_cfg_mode),
            .save_request(config_save_event),
            .service_ready(config_ready),
            .busy(config_busy),
            .load_done(config_load_done),
            .save_done(config_save_done),
            .apply_valid(config_apply_valid),
            .config_rejected(config_rejected),
            .fatal_error(config_fatal_error),
            .error_code(config_error_code),
            .request_dropped(config_request_dropped),
            .stored_config_valid(stored_config_valid),
            .active_version(stored_config_version),
            .live_period_ms(config_period_ms),
            .live_period_cycles(config_period_cycles),
            .live_volume(config_volume),
            .live_mode(config_mode),
            .jedec_id(config_jedec_id),
            .status1(config_status1),
            .status2(config_status2),
            .status3(config_status3),
            .flash_miso(flash_miso),
            .flash_cs_n(flash_cs_n),
            .flash_sclk(flash_sclk),
            .flash_mosi(flash_mosi),
            .flash_wp_n(flash_wp_n),
            .flash_hold_n(flash_hold_n));

    always @(posedge sys_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n)
            config_save_ok_latched <= 1'b0;
        else if (config_save_event)
            config_save_ok_latched <= 0;
        else if (config_save_done && !config_fatal_error)
            config_save_ok_latched <= 1'b1;
    end

    genvar bit_index;
    generate
        for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1) begin : g_image_sync
            sync_2ff u_sync (
                .clk(sys_clk),
                .rst_n(ctrl_rst_n),
                .async_in(image_complete[bit_index]),
                .sync_out(image_complete_sys[bit_index])
            );
        end
    endgenerate

    genvar ek;
    generate
        for (ek = 0; ek < 3; ek = ek + 1) begin : g_emergency_type
            sync_2ff u_sync (
                .clk(pixel_clk),
                .rst_n(pix_rst_n),
                .async_in(emergency_kind[ek]),
                .sync_out(emergency_kind_pix_sync[ek])
            );
        end
    endgenerate
    always @(posedge pixel_clk or negedge pix_rst_n)
        if (!pix_rst_n)
            emergency_kind_pix <= 0;
        else if (frame_start)
            emergency_kind_pix <= emergency_kind_pix_sync;
    emergency_indicators u_emergency_indicators (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .active(fire_frame_sys),
        .kind(emergency_kind),
        .visible(emergency_visible),
        .buzzer_n(buzzer_n)
    );

    // FADE_FRAMES=16 gives roughly a 0.27 s ramp at 640x480@60 on both the
    // fade-out and fade-in halves of a manual switch.

    genvar bright_bit;
    generate
        for (bright_bit = 0; bright_bit < 8; bright_bit = bright_bit + 1) begin : g_bright_sync
            sync_2ff u_sync (
                .clk(pixel_clk),
                .rst_n(pix_rst_n),
                .async_in(brightness_sys[bright_bit]),
                .sync_out(brightness_pix[bright_bit])
            );
        end
    endgenerate

    display_render_pipeline #(
        .FADE_FRAMES(16),
        .SUPPORT_FIRE(1),
        .SUPPORT_MULTI_EMERGENCY(1)
    ) u_video (
        .video_view((video_mode_pix && clip_loaded && !fire_frame) || warm_hold_pix),
        .video_bank(warm_hold_pix ? 1'b0 : clip_bank),
        .burst_request(v_burst_req),
        .burst_words(v_burst_count),
        .burst_grant(v_burst_grant),
        .fire_request(fire_requested),
        .freeze_state(fire_lock || video_mode_sys || warm_active_sys || slot_reload),
        .emergency_kind(emergency_kind_pix_sync),
        .emergency_complete(available_emergency_pages),
        .fire_image_ready(fire_image_ready),
        .fire_active(fire_frame),
        .prev_event((prev_image_event || (remote_allow && remote_command == 6)) && !fire_lock && !video_mode_sys),
        .select_event(select_image_event && !fire_lock && !video_mode_sys),
        .select_index(focus_index_sys),
        .pause_auto(thumbnail_mode_sys),
        .audio_envelope(audio_envelope),
        .brightness(brightness_pix),
        .ctrl_clk(sys_clk),
        .ctrl_rst_n(ctrl_rst_n),
        .next_event((next_image_event || (remote_allow && remote_command == 5)) && !fire_lock && !video_mode_sys),
        .toggle_auto_event(1'b0),
        .period_cfg_valid(config_apply_valid || fire_deferred_config),
        .period_cfg_cycles(config_period_cycles),
        .auto_cfg_valid(config_apply_valid || fire_deferred_config),
        .auto_cfg_enabled(config_mode[0]),
        .image_complete(image_complete_sys),
        .player_enable(player_enable_mem),
        .mem_clk(mem_clk),
        .thumbnail_view(view_pix && !video_mode_pix),
        .thumbnail_active(gallery_active_pix),
        .mem_rst_n(mem_rst_n),
        .controller_init_done(sdram_init_done),
        .controller_busy(sdram_busy || !dma_idle),
        .refresh_active(sdram_refresh_active),
        .app_rd_en(player_app_rd_en),
        .app_rd_addr(player_app_rd_addr),
        .sdram_rd_valid(dma_vreturn),
        .sdram_rd_data(sdram_rd_data),
        .pix_clk(pixel_clk),
        .pix_rst_n(pix_rst_n),
        .video_clk(video_clk),
        .video_hs(video_hs),
        .video_vs(video_vs),
        .video_de(video_de),
        .video_rgb(video_rgb),
        .video_x(video_x),
        .active_index(active_index),
        .pending_index(pending_index),
        .auto_enabled(auto_enabled),
        .frame_start(frame_start),
        .reader_busy(reader_busy),
        .reader_underflow(reader_underflow),
        .video_error(video_error)
    );

    // Audio-video linkage: the displayed image picks the sustained note and
    // the persisted volume scales it. Both are slow, frame-granular signals
    // crossing into the registered video clock domain.

    genvar media_bit;
    generate
        for (media_bit = 0; media_bit < 2; media_bit = media_bit + 1) begin : g_media_sync
            sync_2ff u_sync (
                .clk(video_clk),
                .rst_n(pix_rst_n),
                .async_in(active_index[media_bit]),
                .sync_out(active_index_video[media_bit])
            );
        end
    endgenerate
    generate
        for (media_bit = 0; media_bit < 8; media_bit = media_bit + 1) begin : g_volume_sync
            sync_2ff u_sync (
                .clk(video_clk),
                .rst_n(pix_rst_n),
                .async_in(config_volume[media_bit]),
                .sync_out(volume_video[media_bit])
            );
        end
    endgenerate

    // Audio faults surface as 8'h71 (distinct from the 0x6x reader family
    // and 0x5x control family) so the UART log and the status OSD report the
    // same failure the 4'hd LED shows.
    // Cross-domain status wires (declared before first use to keep
    // synthesis logs free of HDL-5373 used-before-declaration noise).

    // Storage failures surface the real ingest error code (SD init
    // 0x01-0x0c, filesystem 0x10-0x22, decoder 0x31-0x38, loader 0x41-0x46)
    // so the OSD and UART distinguish "no card" (CMD0 timeout) from
    // "no FAT/no BMP"; the blanket 0xFE remains for code-less failures.

    // Publish an immutable code and its valid flag together in sys_clk.
    // The previous direct ingest_error_code -> UART path crossed mem_clk
    // without a coherent snapshot and failed final setup timing.
    sticky_error_cdc u_storage_error_snapshot (
        .src_clk(mem_clk),
        .src_rst_n(mem_rst_n),
        .src_error((thumbnail_done && thumbnail_error != 0) || (ingest_done && boot_retries >= 1 && (ingest_error_stage != 0 || ingest_error_code != 0 || image_complete != 4'hf))),
        .src_code(thumbnail_error != 0       ? thumbnail_error : ingest_error_detail != 0 ? ingest_error_detail : ingest_error_code),
        .src_latched(storage_error_mem),
        .dst_clk(sys_clk),
        .dst_rst_n(ctrl_rst_n),
        .dst_valid(storage_error_sys),
        .dst_code(storage_reported_error)
    );

    sticky_error_cdc u_wav_error_snapshot (
        .src_clk(mem_clk),
        .src_rst_n(mem_rst_n),
        .src_error(wav_error != 0),
        .src_code(wav_error),
        .src_latched(),
        .dst_clk(sys_clk),
        .dst_rst_n(ctrl_rst_n),
        .dst_valid(wav_fault_sys),
        .dst_code(wav_error_sys)
    );
    assign reported_error = warm_error_sys != 0  ? warm_error_sys
                                  : storage_error_sys  ? storage_reported_error
                                  : config_fatal_error ? config_error_code
                                  : video_fault_sys    ? video_error_sys
                                  : audio_fault_sys    ? 8'h71
                                  : wav_fault_sys      ? wav_error_sys
                                                       : 8'd0;

    // Status OSD: bank number, auto mode and fault code rendered in the
    // top-left corner. Purely combinational, so the video_x/video_de
    // alignment feeding the HDMI Data Island scheduler is preserved.

    always @* begin
        if (config_period_ms < 3500)
            period_sel_sys = 2'd0;
        else if (config_period_ms < 7500)
            period_sel_sys = 2'd1;
        else if (config_period_ms < 20000)
            period_sel_sys = 2'd2;
        else
            period_sel_sys = 2'd3;
        case (config_volume)
            8'd0:
                volume_sel_sys = 3'd0;
            8'd64:
                volume_sel_sys = 3'd1;
            8'd128:
                volume_sel_sys = 3'd2;
            8'd192:
                volume_sel_sys = 3'd3;
            default:
                volume_sel_sys = 3'd4;
        endcase
    end

    genvar secbit;
    generate
        for (secbit = 0; secbit < 6; secbit = secbit + 1) begin : g_osd_seconds
            sync_2ff u_sync (
                .clk(video_clk),
                .rst_n(pix_rst_n),
                .async_in(panel_seconds[secbit]),
                .sync_out(osd_period_seconds[secbit])
            );
        end
    endgenerate

    sync_2ff u_auto_osd_sync (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .async_in(auto_enabled),
        .sync_out(auto_enabled_video)
    );
    genvar osd_bit;
    generate
        for (osd_bit = 0; osd_bit < 8; osd_bit = osd_bit + 1) begin : g_osd_err
            sync_2ff u_sync (
                .clk(video_clk),
                .rst_n(pix_rst_n),
                .async_in(reported_error[osd_bit]),
                .sync_out(reported_error_video[osd_bit])
            );
        end
    endgenerate
    genvar osd_param_bit;
    generate
        for (osd_param_bit = 0; osd_param_bit < 2; osd_param_bit = osd_param_bit + 1)
        begin : g_osd_period_brightness
            sync_2ff u_period (
                .clk(video_clk),
                .rst_n(pix_rst_n),
                .async_in(period_sel_sys[osd_param_bit]),
                .sync_out(period_sel_video[osd_param_bit])
            );
            sync_2ff u_brightness (
                .clk(video_clk),
                .rst_n(pix_rst_n),
                .async_in(brightness_level[osd_param_bit]),
                .sync_out(brightness_sel_video[osd_param_bit])
            );
        end
        for (osd_param_bit = 0; osd_param_bit < 3; osd_param_bit = osd_param_bit + 1)
        begin : g_osd_volume
            sync_2ff u_volume (
                .clk(video_clk),
                .rst_n(pix_rst_n),
                .async_in(volume_sel_sys[osd_param_bit]),
                .sync_out(volume_sel_video[osd_param_bit])
            );
        end
    endgenerate

    assign contrast_sys = brightness_level[3:2] == 0   ? 8'd128
                                : brightness_level[3:2] == 1 ? 8'd96
                                : brightness_level[3:2] == 2 ? 8'd160
                                                               : 8'd192;

    genvar cb;
    generate
        for (cb = 0; cb < 8; cb = cb + 1) begin : g_contrast
            sync_2ff u_sync (
                .clk(video_clk),
                .rst_n(pix_rst_n),
                .async_in(contrast_sys[cb]),
                .sync_out(contrast_pix[cb])
            );
        end
    endgenerate

    sync_2ff u_view_sync (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .async_in(thumbnail_mode_sys),
        .sync_out(view_pix)
    );
    generate
        for (cb = 0; cb < 2; cb = cb + 1) begin : g_focus
            sync_2ff u_sync (
                .clk(video_clk),
                .rst_n(pix_rst_n),
                .async_in(focus_index_sys[cb]),
                .sync_out(focus_pix[cb])
            );
        end
    endgenerate

    color_adjust_pipeline u_color (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .hs_in(video_hs),
        .vs_in(video_vs),
        .de_in(video_de),
        .x_in(video_x),
        .rgb_in(video_rgb),
        .contrast(fire_frame ? 8'd128 : contrast_pix),
        .hs_out(color_hs),
        .vs_out(color_vs),
        .de_out(color_de),
        .x_out(color_x),
        .rgb_out(color_rgb)
    );
    thumbnail_gallery_overlay u_thumbnails (
        .pix_clk(video_clk),
        .rst_n(pix_rst_n),
        .hs_in(color_hs),
        .vs_in(color_vs),
        .de_in(color_de),
        .x_in(color_x),
        .rgb_in(color_rgb),
        .view_mode(gallery_active_pix && !fire_frame),
        .focus_index(focus_pix),
        .hs_out(thumb_hs),
        .vs_out(thumb_vs),
        .de_out(thumb_de),
        .x_out(thumb_x),
        .rgb_out(thumb_rgb)
    );
    // SW1 down/ON grounds the official C8 input. Synchronize, debounce for
    // 10 ms, then change visibility only at the start of a complete frame.

    overlay_switch_control u_overlay_switch (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .switch_n(sw1_n),
        .vsync(thumb_vs),
        .hidden(overlay_hidden)
    );
    // 产品说明：SW1仅隐藏普通OSD/字幕/声浪；应急提示必须继续显示，广播弹窗由found关闭。
    assign hide_normal_overlays = overlay_hidden && !fire_frame;
    genvar er;
    generate
        for (er = 0; er < 4; er = er + 1) begin : g_emergency_complete
            sync_2ff u_ready (
                .clk(video_clk),
                .rst_n(pix_rst_n),
                .async_in(available_emergency_pages[er]),
                .sync_out(emergency_complete_pix[er])
            );
        end
    endgenerate

    emergency_scene_fallback #(
        .COMPACT(1)
    ) u_emergency_page (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .vsync(thumb_vs),
        .de(thumb_de),
        .active(fire_frame),
        .kind(emergency_kind_pix),
        .page_ready(emergency_kind_pix >= 1 && emergency_kind_pix <= 4 && emergency_complete_pix[emergency_kind_pix - 1'b1]),
        .x(thumb_x),
        .rgb_in(thumb_rgb),
        .rgb_out(emergency_base_rgb)
    );

    display_status_overlay #(
        .SUPPORT_LIVE_PERIOD(1),
        .SUPPORT_FIRE(1),
        .OSD_X(8),
        .OSD_Y(8)
    ) u_osd (
        .period_seconds(osd_period_seconds),
        .suppress_status(fire_frame || hide_normal_overlays),
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .hsync(thumb_hs),
        .vsync(thumb_vs),
        .de(thumb_de),
        .rgb_in(emergency_base_rgb),
        .pixel_x(thumb_x),
        .active_index(active_index_video),
        .auto_enabled(auto_enabled_video),
        .error_code(reported_error_video),
        .period_sel(period_sel_video),
        .volume_sel(volume_sel_video),
        .brightness_sel(brightness_sel_video),
        .rgb_out(video_rgb_osd),
        .hsync_out(video_hs_osd),
        .vsync_out(video_vs_osd),
        .de_out(video_de_osd),
        .pixel_x_out(video_x_osd),
        .osd_active()
    );

    // Mall display audio visualizer: 64 cyan/blue symmetric envelope bars
    // plus a gold peak meter. Accepted bridge samples drive the history;
    // the compact overlay remains combinational and keeps timing aligned.

    audio_envelope_visualizer #(
        .SUPPORT_FIRE(1),
        .SUPPORT_MULTI_EMERGENCY(1),
        .WAVE_X(56),
        .WAVE_Y(424),
        .WAVE_WIDTH(512),
        .WAVE_HEIGHT(48)
    ) u_audio_waveform (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .vsync(video_vs_osd),
        .de(video_de_osd),
        .rgb_in(video_rgb_osd),
        .pixel_x(video_x_osd),
        .enable(!hide_normal_overlays && !(fire_frame && emergency_kind_pix == 2)),
        .audio_active(fire_frame || volume_video != 8'd0),
        .fire_active(fire_frame),
        .emergency_kind(emergency_kind_pix),
        .pcm_tap_valid(audio_pcm_tap_valid),
        .pcm_tap_left(audio_pcm_tap_left),
        .rgb_out(video_rgb_wave),
        .waveform_active()
    );

    // Mall display subtitle: "欢迎光临  安全购物  美好生活". The 24-pixel
    // Chinese banner runs across the top while preserving timing alignment.

    mall_marquee_overlay #(
        .SUPPORT_FIRE(1),
        .SUPPORT_MULTI_EMERGENCY(1),
        .SUPPORT_BRAM_FONT(1),
        .SUPPORT_HIDE(1),
        .FIRE_Y(28),
        .SUB_Y(32),
        .SCROLL_STEP(2),
        .H_ACT(640)
    ) u_subtitle (
        .emergency_kind(emergency_kind_pix),
        .hide_overlay(hide_normal_overlays),
        .fire_active(fire_frame),
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .hsync(video_hs_osd),
        .vsync(video_vs_osd),
        .de(video_de_osd),
        .pixel_x(video_x_osd),
        .rgb_in(video_rgb_wave),
        .hsync_out(video_hs_sub),
        .vsync_out(video_vs_sub),
        .de_out(video_de_sub),
        .pixel_x_out(video_x_sub),
        .rgb_out(video_rgb_sub),
        .subtitle_active()
    );

    finder_notice_overlay u_notice_overlay (
        .sys_clk(sys_clk),
        .write_en(notice_write),
        .write_address(notice_address),
        .write_data(notice_data),
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .hsync(video_hs_sub),
        .vsync(video_vs_sub),
        .de(video_de_sub),
        .x(video_x_sub),
        .rgb_in(video_rgb_sub),
        .requested_kind(notice_kind_sync),
        .emergency_active(fire_frame),
        .shown_kind(notice_shown),
        .hs_out(notice_hs),
        .vs_out(notice_vs),
        .de_out(notice_de),
        .x_out(notice_x),
        .rgb_out(notice_rgb)
    );

    emergency_halo_overlay #(
        .SUPPORT_MULTI_EMERGENCY(1)
    ) u_fire_glow (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .emergency_kind(emergency_kind_pix),
        .vsync(notice_vs),
        .de(notice_de),
        .fire_active(fire_frame),
        .pixel_x(notice_x),
        .rgb_in(notice_rgb),
        .rgb_out(video_rgb_glow)
    );

    assign boot_status_mem = {boot_failed_mem, player_enable_mem, boot_progress_mem};

    boot_load_progress u_boot_progress (
        .clk(mem_clk),
        .rst_n(mem_rst_n),
        .memory_ready(sdram_init_done),
        .card_ready(card_ready),
        .attempt_start(ingest_start),
        .pixel_valid(tap_valid),
        .gallery_start(thumbnail_start),
        .gallery_write(thumb_wr_en),
        .final_ingest_failure( ingest_done && (ingest_error_stage != 0 || ingest_error_code != 0 || image_complete != 4'hf) && boot_retries != 0),
        .gallery_failure(thumbnail_done && thumbnail_error != 0),
        .player_ready(player_enable_mem),
        .progress(boot_progress_mem),
        .failed(boot_failed_mem)
    );
    status_snapshot_cdc u_boot_status_pix (
        .src_clk(mem_clk),
        .src_rst_n(mem_rst_n),
        .src_value(boot_status_mem),
        .dst_clk(video_clk),
        .dst_rst_n(pix_rst_n),
        .dst_value(boot_status_pix)
    );
    status_snapshot_cdc u_boot_status_sys (
        .src_clk(mem_clk),
        .src_rst_n(mem_rst_n),
        .src_value(boot_status_mem),
        .dst_clk(sys_clk),
        .dst_rst_n(ctrl_rst_n),
        .dst_value(boot_status_sys)
    );
    boot_loading_display u_boot_loading_display (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .vsync(notice_vs),
        .ready(boot_status_pix[8]),
        .failed(boot_status_pix[9]),
        .enable(boot_banner_enable)
    );
    sync_2ff u_warm_failed_pix (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .async_in(warm_error_mem != 0),
        .sync_out(warm_failed_pix)
    );
    generate
        for (wb = 0; wb < 8; wb = wb + 1) begin : g_warm_progress_pix
            sync_2ff u_sync (
                .clk(video_clk),
                .rst_n(pix_rst_n),
                .async_in(warm_progress_mem[wb]),
                .sync_out(warm_progress_pix[wb])
            );
        end
    endgenerate
    loading_banner u_loading (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .vsync(notice_vs),
        .de(notice_de),
        .enable((boot_banner_enable || warm_active_pix) && !fire_frame && notice_shown == 0),
        .failed(warm_failed_pix || boot_status_pix[9]),
        .x(notice_x),
        .progress(warm_active_pix ? warm_progress_pix : boot_status_pix[7:0]),
        .rgb_in(video_rgb_glow),
        .rgb_out(video_rgb_final)
    );
    // Missing/malformed ALARM.WAV retains a hardware siren as a fallback.

    sync_2ff u_alarm_error (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .async_in(alarm_wav_error != 0),
        .sync_out(alarm_error_pix)
    );
    assign notice_audio_select = notice_kind_sync != 0 && !fire_frame;

    assign wav_ready = !video_mode_pix && !notice_audio_select && normal_feed_ready;

    assign use_alarm_wav = !warm_active_pix && alarm_wav_active && alert_ready_pix &&
                         !alert_lost_pix && !alarm_error_pix && emergency_kind_pix != 2;

    assign alarm_wav_ready = notice_audio_select
                                 ? normal_feed_ready && alert_ready_pix && alert_lost_pix
                                 : fire_pcm_ready && use_alarm_wav;
    assign fire_pcm_valid  = use_alarm_wav ? alarm_wav_valid : fallback_valid;
    assign fire_pcm_sample = emergency_kind_pix == 2 ? 16'sd0
                             : use_alarm_wav         ? alarm_left
                                                     : fallback_sample;
    emergency_silent_pcm u_silent_pcm (
        .clk(video_clk),
        .rst_n(pix_rst_n),
        .active((fire_frame && emergency_kind_pix == 2) || (warm_active_pix && !fire_frame)),
        .ready(fire_frame ? fire_pcm_ready : normal_feed_ready),
        .valid(fallback_valid)
    );
    assign fallback_sample = 16'sd0;

    hdmi_pcm_bridge #(
        .DVI_ONLY(HDMI_DVI_ONLY),
        .SUPPORT_FIRE(1),
        .SUPPORT_SHARED_ALARM(1)
    ) u_hdmi_audio_bridge (
        .fire_use_fallback(!use_alarm_wav && emergency_kind_pix != 2),
        .fire_active(fire_frame),
        .fire_valid(fire_pcm_valid),
        .fire_sample(fire_pcm_sample),
        .fire_ready(fire_pcm_ready),
        .wav_active( notice_audio_select ? (alarm_wav_active && alert_ready_pix && alert_lost_pix && !alarm_error_pix) : (video_mode_pix ? 1'b1 : (warm_active_pix || wav_active))),
        .wav_valid(notice_audio_select ? alarm_wav_valid : (video_mode_pix       ? clip_pcm_valid : warm_active_pix ? fallback_valid : wav_valid)),
        .wav_ready(normal_feed_ready),
        .wav_left(notice_audio_select ? alarm_left : (video_mode_pix       ? clip_pcm : warm_active_pix ? 16'sd0 : wav_left)),
        .wav_right(notice_audio_select ? alarm_right : (video_mode_pix       ? clip_pcm : warm_active_pix ? 16'sd0 : wav_right)),
        .envelope(audio_envelope),
        .pixel_clk(video_clk),
        .pixel_rst_n(pix_rst_n),
        .video_hsync(notice_hs),
        .video_vsync(notice_vs),
        .video_de(notice_de),
        .video_x(notice_x),
        .video_rgb(video_rgb_final),
        .media_id(active_index_video),
        .volume(fire_frame ? 8'd255 : volume_video),
        .pcm_tap_valid(audio_pcm_tap_valid),
        .pcm_tap_left(audio_pcm_tap_left),
        .clock_symbol(official_clock_symbol),
        .channel0_symbol(audio_symbol0),
        .channel1_symbol(audio_symbol1),
        .channel2_symbol(audio_symbol2),
        .sequence_error(audio_sequence_error),
        .tone_overflow(audio_tone_overflow),
        .pcm_contract_error(audio_pcm_contract_error),
        .blip_active(audio_blip_active)
    );

    assign audio_phy_phase_error = 1'b0;
    hdmi_phy_wrapper #(
        .DEVICE("EG")
    ) u_hdmi_audio_phy (
        .I_pixel_clk(video_clk),
        .I_serial_clk(pixel_clk_5x),
        .I_rst(!pix_rst_n),
        .I_tmds_channel_0(audio_symbol0),
        .I_tmds_channel_1(audio_symbol1),
        .I_tmds_channel_2(audio_symbol2),
        .I_tmds_channel_clk(official_clock_symbol),
        .O_tmds_ch0_p(HDMI_D0_P),
        .O_tmds_ch1_p(HDMI_D1_P),
        .O_tmds_ch2_p(HDMI_D2_P),
        .O_tmds_clk_p(HDMI_CLK_P)
    );

    sync_2ff u_player_enable_sys (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .async_in(player_enable_mem),
        .sync_out(player_enable_sys)
    );
    sync_2ff u_video_fault_sys (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .async_in(video_error != 0),
        .sync_out(video_fault_sys)
    );
    sync_2ff u_audio_fault_sys (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .async_in(audio_sequence_error || audio_tone_overflow || audio_pcm_contract_error || audio_phy_phase_error),
        .sync_out(audio_fault_sys)
    );

    genvar error_bit_index;
    generate
        for (error_bit_index = 0; error_bit_index < 8; error_bit_index = error_bit_index + 1)
        begin : g_video_error_sync
            sync_2ff u_sync (
                .clk(sys_clk),
                .rst_n(ctrl_rst_n),
                .async_in(video_error[error_bit_index]),
                .sync_out(video_error_sys[error_bit_index])
            );
        end
    endgenerate

    // UART status reporter: boot banner, image switch lines, parameter
    // menu changes and fault codes on the board USB-UART at 115200 8N1.
    genvar uart_bit;
    generate
        for (uart_bit = 0; uart_bit < 2; uart_bit = uart_bit + 1) begin : g_media_sys
            sync_2ff u_sync (
                .clk(sys_clk),
                .rst_n(ctrl_rst_n),
                .async_in(active_index[uart_bit]),
                .sync_out(active_index_sys[uart_bit])
            );
        end
    endgenerate

    always @(posedge sys_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n)
            active_index_sys_q <= 2'd0;
        else
            active_index_sys_q <= active_index_sys;
    end
    assign switch_evt = (active_index_sys != active_index_sys_q);

    sync_2ff u_lost_active (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .async_in(fs_lost_valid),
        .sync_out(lost_active_sys)
    );

    genvar host_ready_bit;
    generate
        for (host_ready_bit = 0; host_ready_bit < 4; host_ready_bit = host_ready_bit + 1)
        begin : g_host_ready
            sync_2ff u_ready (
                .clk(sys_clk),
                .rst_n(ctrl_rst_n),
                .async_in(available_emergency_pages[host_ready_bit]),
                .sync_out(emergency_ready_sys[host_ready_bit])
            );
        end
    endgenerate

    always @(posedge pixel_clk or negedge pix_rst_n)
        if (!pix_rst_n)
            clip_snapshot <= 0;
        else if (frame_start)
            clip_snapshot <= {clip_error,
                clip_frame,
                1'b0,
                gallery_active_pix,
                overlay_hidden,
                clip_buffering,
                clip_playing,
                clip_loaded,
                user_pause_pix,
                video_mode_pix};
    always @(posedge sys_clk or negedge ctrl_rst_n)
        if (!ctrl_rst_n) begin
            clip_sys1 <= 0;
            clip_sys2 <= 0;
        end else begin
            clip_sys1 <= clip_snapshot;
            clip_sys2 <= clip_sys1;
        end
    command_receipt u_receipt (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .remote_valid(remote_valid),
        .remote_command(remote_command),
        .config_ready(config_ready),
        .busy(fire_lock || notice_uploading || warm_active_sys || config_busy),
        .video_mode(video_mode_sys),
        .slot_deferred(video_mode_sys || fire_lock || notice_requested != 0 || notice_uploading || warm_active_sys || config_busy),
        .start_valid(emergency_start),
        .end_valid(emergency_end),
        .start_kind(emergency_start_kind),
        .end_kind(emergency_end_kind),
        .current_kind(emergency_kind),
        .receipt_count(receipt_seq),
        .command(receipt_cmd),
        .status(receipt_status)
    );
    uart_status_reporter #(
        .CLKS_PER_BIT(434),
        .SUPPORT_FINDER(1),
        .SUPPORT_VIDEO(1),
        .SUPPORT_EXPERIENCE(1)
    ) u_uart_report (
        .load_flags({5'd0, (warm_error_sys != 0) || boot_status_sys[9], warm_cache_sys, warm_loading_sys || (!boot_status_sys[8] && !boot_status_sys[9])}),
        .load_progress(warm_active_sys ? warm_progress_sys : boot_status_sys[7:0]),
        .receipt_sequence(receipt_seq),
        .receipt_command(receipt_cmd),
        .receipt_status(receipt_status),
        .config_flags({4'd0, stored_config_valid, config_fatal_error, config_save_ok_latched, config_busy}),
        .manual_counter(manual_switch_counter),
        .selected_slot(selected_slot),
        .video_flags(clip_sys2[7:0]),
        .video_frame(clip_sys2[15:8]),
        .video_fault(clip_sys2[23:16]),
        .notice_kind(notice_requested),
        .notice_id(notice_id),
        .notice_error(notice_error),
        .notice_flags( {notice_visible_sys, lost_active_sys, notice_uploading, notice_mask_ready}),
        .alarm_active(fire_frame_sys),
        .alarm_kind(emergency_kind),
        .ready_pages(emergency_ready_sys),
        .boot_ready(player_enable_sys),
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .enable(1'b1),
        .media_id(active_index_sys),
        .volume(config_volume),
        .period_ms(config_period_ms),
        .auto_enabled(config_mode[0]),
        .switch_event(switch_evt),
        .menu_event(menu_evt),
        .menu_kind(menu_kind),
        .error_code(reported_error),
        .bright_event(brightness_event),
        .bright_value(brightness_sys),
        .uart_tx(uart_tx_o)
    );

    panel_period_counter u_period_count (
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .update_valid(config_apply_valid),
        .period_ms(config_period_ms),
        .seconds(panel_seconds)
    );
    display_segment_panel #(
        .SUPPORT_EMERGENCY(1),
        .SUPPORT_BRIGHTNESS(1)
    ) u_panel (
        .emergency_kind(fire_frame_sys ? emergency_kind : 3'd0),
        .brightness_level(brightness_level[1:0]),
        .bright_event(brightness_event),
        .clk(sys_clk),
        .rst_n(ctrl_rst_n),
        .enable(!fire_frame_sys || emergency_visible),
        .media_id(active_index_sys),
        .volume(config_volume),
        .period_sec(panel_seconds[5:0]),
        .pic_event(switch_evt),
        .vol_event(menu_evt && menu_kind == 0),
        .prd_event(menu_evt && menu_kind == 1),
        .seg_n(seg_bus),
        .dig_n(dig_n)
    );
    assign seg_n = seg_bus[6:0];
    // Competition-facing playback indicators with fault-code priority:
    // storage all-on, config code, audio 4'hD, video code, save-ok 4'b0101,
    // then the running bank/auto/auto state.
    // 产品说明：LED存在优先级：应急、故障、保存成功、普通图号/A-E。0101保存成功锁存会覆盖普通显示。
    assign led = fire_frame_sys           ? (emergency_visible ? 4'hf : 4'h0)
                 : storage_error_sys      ? 4'hf
                 : config_fatal_error     ? {1'b1, config_error_code[2:0]}
                 : audio_fault_sys        ? 4'hd
                 : video_fault_sys        ? video_error_sys[3:0]
                 : config_save_ok_latched ? 4'b0101
                 : player_enable_sys ? {1'b0, auto_enabled, active_index}
                                     : {1'b0, 1'b0, &image_complete_sys, mem_locked & video_locked};
endmodule
`default_nettype wire
