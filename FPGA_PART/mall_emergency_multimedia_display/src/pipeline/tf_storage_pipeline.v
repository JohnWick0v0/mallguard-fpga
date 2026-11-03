// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：整合TF卡服务、媒体装入和帧写入，向SDRAM控制层提交图像数据。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// 设计约定：
// 事务约定：先排空回放缓存与service_busy，再停止CMD18连续读，避免残留扇区归属。
// 切换媒体上下文时必须保持请求者、LBA和返回字节属于同一次完整读事务。

module tf_storage_pipeline #(
    parameter integer SUPPORT_QUIESCE        = 0,
    parameter integer SPI_CLK_DIV          = 4,
    parameter integer SUPPORT_SLOTS        = 0,
    parameter integer LOAD_FIRE            = 0,
    parameter integer LOAD_MULTI_EMERGENCY = 0,
    parameter integer IMAGE_WIDTH          = 640,
    parameter integer IMAGE_HEIGHT         = 480,
    parameter integer ADDR_WIDTH           = 21,
    parameter integer FIFO_DEPTH           = 512,
    parameter integer STALL_TIMEOUT        = 65535
)(
    input wire                     vf_owner,
                                   vf_start,
                                   vf_allow,
    input wire [31:0]              vf_cluster,
                                   vf_size,
    output wire                    vf_valid,
                                   vf_done,
    output wire [7:0]              vf_byte,
                                   vf_error,
    output wire [31:0]             vf_offset,
    output wire                    vf_req,
    output wire [31:0]             vf_lba,
    input wire                     vf_busy,
                                   vf_sector_valid,
                                   vf_sector_done,
    input wire [7:0]               vf_sector_byte,
                                   vf_sector_error,
    input wire [8:0]               vf_sector_index,
    input wire [1:0]               selected_slot,
    output wire [7:0]              fs_spc,
    output wire [31:0]             fs_fat,
                                   fs_data,
                                   fs_max,
                                   fs_audio_cluster,
                                   fs_audio_size,
    output wire                    fs_video_valid,
    output wire [31:0]             fs_video_cluster,
                                   fs_video_size,
    output wire                    fs_audio_valid,
    output wire                    fs_lost_valid,
    output wire [31:0]             fs_lost_cluster,
                                   fs_lost_size,
    output wire                    fs_alarm_valid,
    output wire [31:0]             fs_alarm_cluster,
                                   fs_alarm_size,
    output wire [3:0]              emergency_complete,
    output wire                    fire_complete,
    output wire [7:0]              fire_error,
    output wire                    tap_valid,
    output wire [23:0]             tap_rgb,
    output wire [15:0]             tap_x,
                                   tap_y,
    output wire [1:0]              tap_image,
    input wire                     audio_sector_req,
    input wire [31:0]              audio_sector_lba,
    output wire                    audio_sector_busy,
                                   audio_sector_valid,
                                   audio_sector_done,
    output wire [7:0]              audio_sector_byte,
                                   audio_sector_error,
    output wire [8:0]              audio_sector_byte_index,
    input wire                     clk,
    input wire                     rst_n,
    input wire                     quiesce,
    output wire                    quiescent,
    input wire                     start,
    output wire                    busy,
    output reg                     done,
    output reg [2:0]               error_stage,
    output reg [7:0]               error_code,
    output reg [7:0]               error_detail,
    output wire                    card_ready,
    output wire                    card_high_capacity,
    output wire [3:0]              resource_valid,
    output wire [3:0]              image_complete,
    input wire                     controller_init_done,
    input wire                     controller_busy,
    input wire                     refresh_active,
    output wire                    write_reserved,
    output wire                    app_wr_en,
    output wire [ADDR_WIDTH - 1:0] app_wr_addr,
    output wire [3:0]              app_wr_mask,
    output wire [31:0]             app_wr_data,
    output wire                    sd_cs_n,
    output wire                    sd_sclk,
    output wire                    sd_mosi,
    input wire                     sd_miso
);
    localparam ST_IDLE          = 2'd0;
    localparam ST_INIT          = 2'd1;
    localparam ST_INGEST        = 2'd2;
    localparam ERR_STAGE_NONE   = 3'd0;
    localparam ERR_STAGE_INIT   = 3'd1;
    localparam ERR_STAGE_INGEST = 3'd2;

    reg [1:0] state;
    reg init_start;
    reg ingest_start;
    wire init_done;
    wire [7:0] init_error;
    wire service_sector_req;
    wire [31:0] service_sector_lba;
    wire service_sector_busy;
    wire service_sector_done;
    wire service_sector_valid;
    wire [7:0] service_sector_byte;
    wire [8:0] service_sector_byte_index;
    wire [7:0] service_sector_error;
    wire ingest_done;
    wire [7:0] ingest_error;
    wire [7:0] ingest_detail_error;

    reg audio_owner;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            audio_owner <= 0;
        else if (ingest_done && ingest_error == 0)
            audio_owner <= 1;
    assign audio_sector_busy       = !audio_owner || service_sector_busy;
    assign audio_sector_valid      = audio_owner && service_sector_valid;
    assign audio_sector_done       = audio_owner && service_sector_done;
    assign audio_sector_byte       = service_sector_byte;
    assign audio_sector_byte_index = service_sector_byte_index;
    assign audio_sector_error      = service_sector_error;
    assign busy                    = state != ST_IDLE;

    wire raw_req, raw_busy, raw_valid, raw_done;
    wire [31:0] raw_lba;
    wire [7:0] raw_byte, raw_error;
    wire [8:0] raw_index;
    // Drain the replay buffer before closing CMD18. CS alone cannot tell
    // whether its last sector is still being replayed into a consumer.
    wire close_stream =
             SUPPORT_QUIESCE && quiesce && audio_owner && !service_sector_busy && !raw_req;
    assign quiescent = !service_sector_busy && !raw_busy && !raw_req && sd_cs_n;
    sd_sector_replay_buffer u_shared_replay (
        .clk(clk),
        .rst_n(rst_n),
        .sector_req(audio_owner ? audio_sector_req : service_sector_req),
        .sector_lba(audio_owner ? audio_sector_lba : service_sector_lba),
        .sector_busy(service_sector_busy),
        .sector_valid(service_sector_valid),
        .sector_done(service_sector_done),
        .sector_byte(service_sector_byte),
        .sector_byte_index(service_sector_byte_index),
        .sector_error(service_sector_error),
        .reader_req(raw_req),
        .reader_lba(raw_lba),
        .reader_busy(raw_busy),
        .reader_valid(raw_valid),
        .reader_done(raw_done),
        .reader_byte(raw_byte),
        .reader_byte_index(raw_index),
        .reader_error(raw_error)
    );
    sd_media_service #(
        .SPI_CLK_DIV(SPI_CLK_DIV),
        .SUPPORT_QUIESCE(SUPPORT_QUIESCE)
    ) u_sd_service (
        .clk(clk),
        .rst_n(rst_n),
        .quiesce(close_stream),
        .init_start(init_start),
        .init_busy(),
        .init_done(init_done),
        .init_ready(card_ready),
        .init_error(init_error),
        .card_high_capacity(card_high_capacity),
        .card_ocr(),
        .owner_reader(),
        .sector_req(raw_req),
        .sector_lba(raw_lba),
        .sector_busy(raw_busy),
        .sector_done(raw_done),
        .sector_valid(raw_valid),
        .sector_byte(raw_byte),
        .sector_byte_index(raw_index),
        .sector_error(raw_error),
        .sd_cs_n(sd_cs_n),
        .sd_sclk(sd_sclk),
        .sd_mosi(sd_mosi),
        .sd_miso(sd_miso)
    );

    tf_media_frontend #(
        .SUPPORT_SLOTS(SUPPORT_SLOTS),
        .LOAD_FIRE(LOAD_FIRE),
        .LOAD_MULTI_EMERGENCY(LOAD_MULTI_EMERGENCY),
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .STALL_TIMEOUT(STALL_TIMEOUT)
    ) u_ingest_frontend (
        .vf_allow(vf_allow),
        .vf_owner(vf_owner),
        .vf_start(vf_start),
        .vf_cluster(vf_cluster),
        .vf_size(vf_size),
        .vf_valid(vf_valid),
        .vf_done(vf_done),
        .vf_byte(vf_byte),
        .vf_error(vf_error),
        .vf_offset(vf_offset),
        .vf_req(vf_req),
        .vf_lba(vf_lba),
        .vf_busy(vf_busy),
        .vf_sector_valid(vf_sector_valid),
        .vf_sector_done(vf_sector_done),
        .vf_sector_byte(vf_sector_byte),
        .vf_sector_index(vf_sector_index),
        .vf_sector_error(vf_sector_error),
        .selected_slot(selected_slot),
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
        .emergency_complete(emergency_complete),
        .fire_complete(fire_complete),
        .fire_error(fire_error),
        .tap_valid(tap_valid),
        .tap_rgb(tap_rgb),
        .tap_x(tap_x),
        .tap_y(tap_y),
        .tap_image(tap_image),
        .clk(clk),
        .rst_n(rst_n),
        .start(ingest_start),
        .busy(),
        .done(ingest_done),
        .ingest_error(ingest_error),
        .ingest_detail_error(ingest_detail_error),
        .current_image(),
        .resource_valid(resource_valid),
        .image_complete(image_complete),
        .reader_req(service_sector_req),
        .reader_lba(service_sector_lba),
        .reader_busy(service_sector_busy),
        .reader_valid(service_sector_valid),
        .reader_byte(service_sector_byte),
        .reader_byte_index(service_sector_byte_index),
        .reader_done(service_sector_done),
        .reader_error(service_sector_error),
        .controller_init_done(controller_init_done),
        .controller_busy(controller_busy),
        .refresh_active(refresh_active),
        .write_reserved(write_reserved),
        .app_wr_en(app_wr_en),
        .app_wr_addr(app_wr_addr),
        .app_wr_mask(app_wr_mask),
        .app_wr_data(app_wr_data)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            init_start   <= 1'b0;
            ingest_start <= 1'b0;
            done         <= 1'b0;
            error_stage  <= ERR_STAGE_NONE;
            error_code   <= 8'd0;
            error_detail <= 8'd0;
        end else begin
            init_start   <= 1'b0;
            ingest_start <= 1'b0;
            done         <= 1'b0;
            case (state)
                ST_IDLE:
                    if (start) begin
                        error_stage  <= ERR_STAGE_NONE;
                        error_code   <= 8'd0;
                        error_detail <= 8'd0;
                        init_start   <= 1'b1;
                        state        <= ST_INIT;
                    end
                ST_INIT:
                    if (init_done) begin
                        if (!card_ready || init_error != 0) begin
                            error_stage  <= ERR_STAGE_INIT;
                            error_code   <= init_error;
                            error_detail <= init_error;
                            done         <= 1'b1;
                            state        <= ST_IDLE;
                        end else begin
                            ingest_start <= 1'b1;
                            state        <= ST_INGEST;
                        end
                    end
                ST_INGEST:
                    if (ingest_done) begin
                        if (ingest_error != 0) begin
                            error_stage  <= ERR_STAGE_INGEST;
                            error_code   <= ingest_error;
                            error_detail <= ingest_detail_error;
                        end
                        done  <= 1'b1;
                        state <= ST_IDLE;
                    end
                default:
                    state <= ST_IDLE;
            endcase
        end
    end
endmodule
