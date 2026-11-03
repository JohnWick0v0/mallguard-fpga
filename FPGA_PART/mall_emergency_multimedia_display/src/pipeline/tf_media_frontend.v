// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：封装TF媒体装入启动、目录信息与错误输出，供存储服务统一调用。
// 时钟：clk。
// 复位：rst_n（向子模块传递，语义见子模块）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

module tf_media_frontend #(
    parameter integer SUPPORT_SLOTS          = 0,
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
    input wire                     clk,
    input wire                     rst_n,
    input wire                     start,
    output wire                    busy,
    output wire                    done,
    output wire [7:0]              ingest_error,
    output wire [7:0]              ingest_detail_error,
    output wire [1:0]              current_image,
    output wire [3:0]              resource_valid,
    output wire [3:0]              image_complete,
    output wire                    reader_req,
    output wire [31:0]             reader_lba,
    input wire                     reader_busy,
    input wire                     reader_valid,
    input wire [7:0]               reader_byte,
    input wire [8:0]               reader_byte_index,
    input wire                     reader_done,
    input wire [7:0]               reader_error,
    input wire                     controller_init_done,
    input wire                     controller_busy,
    input wire                     refresh_active,
    output wire                    write_reserved,
    output wire                    app_wr_en,
    output wire [ADDR_WIDTH - 1:0] app_wr_addr,
    output wire [3:0]              app_wr_mask,
    output wire [31:0]             app_wr_data
);
    wire replay_busy;
    wire replay_valid;
    wire [7:0] replay_byte;
    wire [8:0] replay_byte_index;
    wire replay_done;
    wire [7:0] replay_error;
    wire ingest_sector_req;
    wire [31:0] ingest_sector_lba;
    wire ingest_busy;

    assign busy = ingest_busy || replay_busy;

    assign reader_req        = ingest_sector_req;
    assign reader_lba        = ingest_sector_lba;
    assign replay_busy       = reader_busy;
    assign replay_valid      = reader_valid;
    assign replay_byte       = reader_byte;
    assign replay_byte_index = reader_byte_index;
    assign replay_done       = reader_done;
    assign replay_error      = reader_error;

    tf_media_ingest_pipeline #(
        .SUPPORT_SLOTS(SUPPORT_SLOTS),
        .LOAD_FIRE(LOAD_FIRE),
        .LOAD_MULTI_EMERGENCY(LOAD_MULTI_EMERGENCY),
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .STALL_TIMEOUT(STALL_TIMEOUT)
    ) u_ingest_pipeline (
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
        .start(start),
        .busy(ingest_busy),
        .done(done),
        .ingest_error(ingest_error),
        .ingest_detail_error(ingest_detail_error),
        .current_image(current_image),
        .resource_valid(resource_valid),
        .image_complete(image_complete),
        .sector_req(ingest_sector_req),
        .sector_lba(ingest_sector_lba),
        .sector_busy(replay_busy),
        .sector_valid(replay_valid),
        .sector_byte(replay_byte),
        .sector_byte_index(replay_byte_index),
        .sector_done(replay_done),
        .sector_error(replay_error),
        .controller_init_done(controller_init_done),
        .controller_busy(controller_busy),
        .refresh_active(refresh_active),
        .write_reserved(write_reserved),
        .app_wr_en(app_wr_en),
        .app_wr_addr(app_wr_addr),
        .app_wr_mask(app_wr_mask),
        .app_wr_data(app_wr_data)
    );
endmodule
