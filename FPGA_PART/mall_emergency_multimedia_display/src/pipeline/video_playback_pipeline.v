// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：整合视频包预缓冲、BC1解码、双帧提交与音频主时钟同步。
// 时钟：mem_clk、pix_clk。
// 复位：engine_rst_n（低有效异步复位）；engine_pix_rst_n（低有效异步复位）；mem_rst_n（向子模块传递，语义见子模块）；pix_rst_n（向子模块传递，语义见子模块）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
`include "src/video/video_media_layout.vh"
// 产品说明：环形包缓存提供短暂停顿容忍；不能提前停止活跃TF扇区，暂停与帧提交必须保持音画同步。
// 设计约定：
// 环形槽约定：一个媒体槽必须同时被视频与音频消费者释放，才能交还加载器复用。
// 播放器暂停/应急让行不等于丢弃当前扇区，读卡事务边界由存储链路维护。

module video_playback_pipeline
    #(parameter integer SUPPORT_MAINTENANCE = 0,
        parameter integer FRAMES            = `CLIP_FRAMES,
        FILE_BYTES                          = `CLIP_BYTES,
        RING_BITS                           = 3,
        PREFILL_FRAMES                      = 6,
        parameter [31:0] HEADER_CRC       = `CLIP_HEADER_CRC)
    (input wire mem_clk, mem_rst_n, pix_clk, pix_rst_n,
        input wire maintenance, clear_stream,
        input wire controller_ready, controller_busy, refresh,
        output wire app_rd_en,
        output wire [20:0] app_rd_addr,
        output wire app_wr_en,
        output wire [20:0] app_wr_addr,
        output wire [31:0] app_wr_data,
        input wire rd_valid,
        input wire [31:0] rd_data,
        input wire vblank, active_pixel, play_enable,
        input wire v_req, v_en,
        input wire [7:0] v_count,
        input wire [20:0] v_addr,
        output wire v_grant, vr, dma_idle, active_bank,
        output wire pcm_valid,
        output wire signed [15:0] pcm_sample,
        output wire loaded, playing, buffering,
        output wire [7:0] frame_number,
        output wire [7:0] error_code,
        output wire vf_start, vf_allow,
        input wire vf_valid, vf_done,
        input wire [7:0] vf_byte, vf_error,
        input wire [31:0] vf_offset,
        input wire directory_ready, directory_valid,
        input wire [31:0] directory_cluster, directory_size,
        input wire [7:0] directory_spc,
        input wire [31:0] directory_fat, directory_data, directory_max,
        output wire sector_req,
        output wire [31:0] sector_lba,
        input wire sector_busy, sector_valid, sector_done,
        input wire [7:0] sector_byte, sector_error,
        input wire [8:0] sector_byte_index);
    wire maint        = SUPPORT_MAINTENANCE && maintenance;
    wire engine_rst_n = mem_rst_n && !(SUPPORT_MAINTENANCE && clear_stream);
    wire clear_pix;
    sync_2ff u_maintenance_sync (
        .clk(pix_clk),
        .rst_n(pix_rst_n),
        .async_in(SUPPORT_MAINTENANCE && clear_stream),
        .sync_out(clear_pix)
    );
    wire engine_pix_rst_n = pix_rst_n && !clear_pix;
    // Producer and both consumers use monotonic modulo-65536 frame counters.
    // A ring slot is reusable only after BOTH its video and PCM reads finish.
    reg [RING_BITS:0] produced, decoded, audio_read;
    reg [RING_BITS - 1:0] source_slot, decode_slot, audio_slot;
    wire [RING_BITS:0] video_distance = produced - decoded,
                         audio_distance = produced - audio_read;
    wire source_pending;
    reg source_accept;
    wire source_word_valid, source_word_ready;
    wire [31:0] source_word;
    wire [7:0] source_error;
    wire allow_read =
             video_distance < (1 << RING_BITS) - 1 && audio_distance < (1 << RING_BITS) - 1;
    video_packet_loader #(
        .FILE_BYTES(FILE_BYTES),
        .FRAMES(FRAMES),
        .HEADER_CRC(HEADER_CRC)
    ) u_loader (
        .clk(mem_clk),
        .rst_n(engine_rst_n),
        .controller_ready(controller_ready && !maint),
        .allow_read(allow_read && !maint),
        .frame_accept(source_accept),
        .word_valid(source_word_valid),
        .word_data(source_word),
        .word_ready(source_word_ready),
        .frame_pending(source_pending),
        .error(source_error),
        .vf_allow(vf_allow),
        .vf_start(vf_start),
        .vf_valid(vf_valid),
        .vf_done(vf_done),
        .vf_byte(vf_byte),
        .vf_error(vf_error),
        .vf_offset(vf_offset),
        .directory_ready(directory_ready),
        .directory_valid(directory_valid),
        .directory_cluster(directory_cluster),
        .directory_size(directory_size),
        .directory_spc(directory_spc),
        .directory_fat(directory_fat),
        .directory_data(directory_data),
        .directory_max(directory_max),
        .sector_req(sector_req),
        .sector_lba(sector_lba),
        .sector_busy(sector_busy),
        .sector_valid(sector_valid),
        .sector_done(sector_done),
        .sector_byte(sector_byte),
        .sector_error(sector_error),
        .sector_byte_index(sector_byte_index)
    );
    wire sf_full, sf_valid, sf_pop;
    wire [31:0] sf_head;
    wire [8:0] sf_level;
    reg [10:0] sf_available;
    assign source_word_ready = !sf_full;
    demo_fifo #(
        .AW(8)
    ) u_source_fifo (
        .wr_clk(mem_clk),
        .wr_rst_n(engine_rst_n),
        .push(source_word_valid),
        .data(source_word),
        .full(sf_full),
        .level(sf_level),
        .rd_clk(mem_clk),
        .rd_rst_n(engine_rst_n),
        .pop(sf_pop),
        .valid(sf_valid),
        .head(sf_head)
    );
    always @(posedge mem_clk or negedge engine_rst_n)
        if (!engine_rst_n)
            sf_available <= 0;
        else
            case ({source_word_valid && !sf_full, sf_pop && sf_valid})
                2'b10:
                    sf_available <= sf_available + 1'b1;
                2'b01:
                    sf_available <= sf_available - 1'b1;
                default:
                    sf_available <= sf_available;
            endcase

    reg first_frame_ready, primed;
    reg [3:0] engine;
    reg [2:0] clear_count;
    reg [7:0] frame_index;
    reg bank;
    reg ready_toggle, ready_bank;
    reg [7:0] ready_index;
    wire ack_toggle;
    reg ack1, ack2;
    wire comp_rst_n = engine_rst_n && engine != 1 && engine != 2;
    wire dec_busy, dec_done;
    wire [7:0] dec_error;
    wire dec_valid, dec_ready;
    wire [31:0] dec_data;
    reg dec_finished;
    wire packet_valid, packet_pop, packet_full;
    wire [31:0] packet_head;
    wire [8:0] packet_level;
    wire dec_byte_ready;
    reg [1:0] packet_phase;
    wire byte_take    = packet_valid && dec_byte_ready;
    assign packet_pop = byte_take && packet_phase == 3;
    bc1_frame_decoder u_decoder (
        .clk(mem_clk),
        .rst_n(engine_rst_n),
        .start(engine == 3),
        .byte_valid(packet_valid && engine == 4),
        .byte_data(packet_head[packet_phase * 8 +: 8]),
        .byte_ready(dec_byte_ready),
        .word_valid(dec_valid),
        .word_data(dec_data),
        .word_ready(dec_ready),
        .busy(dec_busy),
        .done(dec_done),
        .error(dec_error)
    );
    wire df_full, df_valid, df_pop;
    wire [31:0] df_head;
    wire [8:0] df_level;
    reg [10:0] df_available;
    assign dec_ready = !df_full;
    demo_fifo #(
        .AW(8)
    ) u_decode_fifo (
        .wr_clk(mem_clk),
        .wr_rst_n(engine_rst_n),
        .push(dec_valid && dec_ready),
        .data(dec_data),
        .full(df_full),
        .level(df_level),
        .rd_clk(mem_clk),
        .rd_rst_n(engine_rst_n),
        .pop(df_pop),
        .valid(df_valid),
        .head(df_head)
    );
    always @(posedge mem_clk or negedge engine_rst_n)
        if (!engine_rst_n)
            df_available <= 0;
        else
            case ({dec_valid && dec_ready, df_pop && df_valid})
                2'b10:
                    df_available <= df_available + 1'b1;
                2'b01:
                    df_available <= df_available - 1'b1;
                default:
                    df_available <= df_available;
            endcase

    wire a_grant, a_done, p_grant, s_grant, s_done, d_grant, d_done, ar, pr;
    wire [31:0] return_data;
    wire [7:0] dma_error;
    reg [14:0] source_issued, source_written, packet_issued;
    reg [17:0] decode_issued, decode_written;
    reg [11:0] audio_offset;
    reg audio_last_pending;
    wire [20:0] source_base = 21'd1689600 + source_slot * 21'd `CLIP_FRAME_WORDS;
    wire [20:0] packet_base = 21'd1689600 + decode_slot * 21'd `CLIP_FRAME_WORDS;
    wire [20:0] audio_base =
                      21'd1689600 + audio_slot * 21'd `CLIP_FRAME_WORDS + 21'd `CLIP_VIDEO_WORDS;
    wire [20:0] decode_base = bank ? 21'd1536000 : 21'd1382400;
    wire audio_full, audio_head_valid, audio_pop;
    wire [31:0] audio_head;
    wire [8:0] audio_level;
    wire audio_req = !maint && produced != audio_read && !audio_last_pending && audio_level < 128 &&
                     !audio_full;
    wire [7:0] audio_count = audio_offset == 2368 ? 8'd32 : 8'd64;
    wire packet_req = !maint && engine == 4 && dec_busy && packet_level < 160 && !packet_full &&
                      packet_issued < `CLIP_VIDEO_WORDS;
    stream_sdram_dma u_dma (
        .clk(mem_clk),
        .rst_n(mem_rst_n),
        .init_done(controller_ready),
        .controller_busy(controller_busy),
        .refresh(refresh),
        .v_req(v_req),
        .v_count(v_count),
        .v_grant(v_grant),
        .v_en(v_en),
        .v_addr(v_addr),
        .a_req(audio_req),
        .a_count(audio_count),
        .a_addr(audio_base + audio_offset),
        .a_grant(a_grant),
        .a_done(a_done),
        .p_req(packet_req),
        .p_addr(packet_base + packet_issued),
        .p_grant(p_grant),
        .s_req(sf_available >= 128 && !maint),
        .s_valid(sf_valid),
        .s_data(sf_head),
        .s_addr(source_base + source_issued),
        .s_pop(sf_pop),
        .s_grant(s_grant),
        .s_done(s_done),
        .d_req(df_available >= 128 && !maint),
        .d_valid(df_valid),
        .d_data(df_head),
        .d_addr(decode_base + decode_issued),
        .d_pop(df_pop),
        .d_grant(d_grant),
        .d_done(d_done),
        .app_rd_en(app_rd_en),
        .app_rd_addr(app_rd_addr),
        .app_wr_en(app_wr_en),
        .app_wr_addr(app_wr_addr),
        .app_wr_data(app_wr_data),
        .rd_valid(rd_valid),
        .rd_data(rd_data),
        .video_return(vr),
        .audio_return(ar),
        .packet_return(pr),
        .return_data(return_data),
        .idle(dma_idle),
        .error(dma_error)
    );
    demo_fifo #(
        .AW(8)
    ) u_packet_fifo (
        .wr_clk(mem_clk),
        .wr_rst_n(comp_rst_n),
        .push(pr),
        .data(return_data),
        .full(packet_full),
        .level(packet_level),
        .rd_clk(mem_clk),
        .rd_rst_n(comp_rst_n),
        .pop(packet_pop),
        .valid(packet_valid),
        .head(packet_head)
    );
    demo_fifo #(
        .AW(8)
    ) u_pcm_fifo (
        .wr_clk(mem_clk),
        .wr_rst_n(engine_rst_n),
        .push(ar),
        .data(return_data),
        .full(audio_full),
        .level(audio_level),
        .rd_clk(pix_clk),
        .rd_rst_n(engine_pix_rst_n),
        .pop(audio_pop),
        .valid(audio_head_valid),
        .head(audio_head)
    );
    always @(posedge mem_clk or negedge engine_rst_n) begin
        if (!engine_rst_n) begin
            produced           <= 0;
            decoded            <= 0;
            audio_read         <= 0;
            source_slot        <= 0;
            decode_slot        <= 0;
            audio_slot         <= 0;
            source_accept      <= 0;
            source_issued      <= 0;
            source_written     <= 0;
            packet_issued      <= 0;
            decode_issued      <= 0;
            decode_written     <= 0;
            audio_offset       <= 0;
            audio_last_pending <= 0;
            first_frame_ready  <= 0;
            primed             <= 0;
            engine             <= 0;
            clear_count        <= 0;
            frame_index        <= 0;
            bank               <= 0;
            ready_toggle       <= 0;
            ready_bank         <= 0;
            ready_index        <= 0;
            ack1               <= 0;
            ack2               <= 0;
            packet_phase       <= 0;
            dec_finished       <= 0;
        end else begin
            source_accept <= 0;
            ack1          <= ack_toggle;
            ack2          <= ack1;
            if (s_grant)
                source_issued <= source_issued + 128;
            if (s_done)
                source_written <= source_written + 128;
            if (source_pending && !source_accept && source_written == `CLIP_FRAME_WORDS &&
                sf_available == 0) begin
                produced       <= produced + 1'b1;
                source_slot    <= source_slot + 1'b1;
                source_issued  <= 0;
                source_written <= 0;
                source_accept  <= 1;
            end
            if (primed && produced >= PREFILL_FRAMES)
                first_frame_ready <= 1;
            if (a_grant) begin
                if (audio_offset == 2368)
                    audio_last_pending <= 1;
                else
                    audio_offset <= audio_offset + 64;
            end
            if (a_done && audio_last_pending) begin
                audio_last_pending <= 0;
                audio_offset       <= 0;
                audio_read         <= audio_read + 1'b1;
                audio_slot         <= audio_slot + 1'b1;
            end
            if (p_grant)
                packet_issued <= packet_issued + 64;
            if (d_grant)
                decode_issued <= decode_issued + 128;
            if (d_done)
                decode_written <= decode_written + 128;
            if (byte_take)
                packet_phase <= packet_phase + 1'b1;
            if (dec_done)
                dec_finished <= 1;
            case (engine)
                0:
                    if (produced != decoded)
                        engine <= 1;
                1: begin
                    packet_phase   <= 0;
                    packet_issued  <= 0;
                    decode_issued  <= 0;
                    decode_written <= 0;
                    dec_finished   <= 0;
                    clear_count    <= 4;
                    engine         <= 2;
                end
                2:
                    if (clear_count != 0)
                        clear_count <= clear_count - 1'b1;
                    else
                        engine <= 3;
                3:
                    engine <= 4;
                4:
                    if (dec_finished && decode_written == 153600 && df_available == 0) begin
                        decoded     <= decoded + 1'b1;
                        decode_slot <= decode_slot + 1'b1;
                        if (!primed) begin
                            primed      <= 1;
                            frame_index <= 1;
                            bank        <= 1;
                            engine      <= 0;
                        end else begin
                            ready_toggle <= ~ready_toggle;
                            ready_index  <= frame_index;
                            ready_bank   <= bank;
                            engine       <= 5;
                        end
                    end
                5:
                    if (ack2 == ready_toggle) begin
                        frame_index <= frame_index == FRAMES - 1 ? 0 : frame_index + 1'b1;
                        bank        <= ~bank;
                        engine      <= 0;
                    end
                default:
                    engine <= 0;
            endcase
        end
    end
    wire first_pix, pcm_resume_pix;
    reg armed;
    wire [7:0] audio_index, clock_error;
    sync_2ff u_pcm_resume (
        .clk(pix_clk),
        .rst_n(engine_pix_rst_n),
        .async_in(audio_level >= 160),
        .sync_out(pcm_resume_pix)
    );
    wire [7:0] mem_error = source_error != 0 ? source_error
                             : dma_error != 0  ? dma_error
                                               : dec_error;
    wire [7:0] mem_error_pix, reader_error_pix;
    wire underflow_sticky     = 0;
    wire [7:0] reader_error = 0;
    genvar b;
    generate
        for (b = 0; b < 8; b = b + 1) begin : g_error
            sync_2ff u_sync (
                .clk(pix_clk),
                .rst_n(engine_pix_rst_n),
                .async_in(mem_error[b]),
                .sync_out(mem_error_pix[b])
            );
            sync_2ff u_reader_sync (
                .clk(pix_clk),
                .rst_n(engine_pix_rst_n),
                .async_in(reader_error[b]),
                .sync_out(reader_error_pix[b])
            );
        end
    endgenerate
    sync_2ff u_first (
        .clk(pix_clk),
        .rst_n(engine_pix_rst_n),
        .async_in(first_frame_ready),
        .sync_out(first_pix)
    );
    assign loaded = first_pix;
    always @(posedge pix_clk or negedge engine_pix_rst_n)
        if (!engine_pix_rst_n)
            armed <= 0;
        else if (vblank && first_pix)
            armed <= 1;
    assign error_code = mem_error_pix != 0 ? mem_error_pix
                        : clock_error != 0 ? clock_error
                        : underflow_sticky ? 8'hd3
                                           : reader_error_pix;
    av_playback_clock #(
        .FRAMES(FRAMES)
    ) u_av_clock (
        .clk(pix_clk),
        .rst_n(engine_pix_rst_n),
        .armed(armed),
        .play_enable( play_enable && mem_error_pix == 0 && !underflow_sticky && reader_error_pix == 0),
        .vblank(vblank),
        .pcm_head_valid(audio_head_valid),
        .pcm_resume_ready(pcm_resume_pix),
        .pcm_head(audio_head),
        .pcm_pop(audio_pop),
        .pcm_valid(pcm_valid),
        .pcm_sample(pcm_sample),
        .buffering(buffering),
        .ready_toggle(ready_toggle),
        .ready_index(ready_index),
        .ready_bank(ready_bank),
        .ack_toggle(ack_toggle),
        .active_bank(active_bank),
        .video_index(frame_number),
        .audio_index(audio_index),
        .error(clock_error),
        .playing(playing),
        .loops()
    );
endmodule
