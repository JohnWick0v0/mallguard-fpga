// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：连接卷扫描、文件读取与BMP解码，控制多张广告和应急图像装入。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

module tf_media_ingest_pipeline #(
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
    output reg [3:0]               emergency_complete,
    output reg                     fire_complete,
    output reg [7:0]               fire_error,
    output wire                    tap_valid,
    output wire [23:0]             tap_rgb,
    output wire [15:0]             tap_x,
                                   tap_y,
    output wire [1:0]              tap_image,
    input wire                     clk,
    input wire                     rst_n,
    input wire                     start,
    output wire                    busy,
    output reg                     done,
    output reg [7:0]               ingest_error,
    output reg [7:0]               ingest_detail_error,
    output reg [1:0]               current_image,
    output wire [3:0]              resource_valid,
    output wire [3:0]              image_complete,
    output wire                    sector_req,
    output wire [31:0]             sector_lba,
    input wire                     sector_busy,
    input wire                     sector_valid,
    input wire [7:0]               sector_byte,
    input wire [8:0]               sector_byte_index,
    input wire                     sector_done,
    input wire [7:0]               sector_error,
    input wire                     controller_init_done,
    input wire                     controller_busy,
    input wire                     refresh_active,
    output wire                    write_reserved,
    output wire                    app_wr_en,
    output wire [ADDR_WIDTH - 1:0] app_wr_addr,
    output wire [3:0]              app_wr_mask,
    output wire [31:0]             app_wr_data
);
    localparam integer IMAGE_WORDS = IMAGE_WIDTH * IMAGE_HEIGHT;
    localparam ERR_NONE            = 8'h00;
    localparam ERR_SCAN            = 8'h80;
    localparam ERR_FILE            = 8'h82;
    localparam ERR_BMP             = 8'h83;
    localparam ERR_MEMORY          = 8'h84;

    localparam ST_IDLE       = 3'd0;
    localparam ST_SCAN       = 3'd1;
    localparam ST_FILE_START = 3'd2;
    localparam ST_FILE       = 3'd3;
    localparam ST_FAIL_WAIT  = 3'd4;

    reg [2:0] state;
    wire fire_valid;
    wire [31:0] fire_cluster, fire_size;
    reg fire_loading;
    reg [1:0] emergency_index;
    wire [2:0] extra_valid;
    wire [95:0] extra_clusters, extra_sizes;
    wire selected_emergency_valid =
             emergency_index == 0 ? fire_valid : extra_valid[emergency_index - 1'b1];
    wire [31:0] selected_emergency_cluster = emergency_index == 0   ? fire_cluster
                                               : emergency_index == 1 ? extra_clusters[31:0]
                                               : emergency_index == 2 ? extra_clusters[63:32]
                                                                      : extra_clusters[95:64];
    wire [31:0] selected_emergency_size    = emergency_index == 0   ? fire_size
                                               : emergency_index == 1 ? extra_sizes[31:0]
                                               : emergency_index == 2 ? extra_sizes[63:32]
                                                                      : extra_sizes[95:64];
    wire [ADDR_WIDTH - 1:0] emergency_base =
                                  emergency_index == 0   ? IMAGE_WORDS * 4 + IMAGE_WORDS / 2
                                  : emergency_index == 1 ? IMAGE_WORDS * 5
                                  : emergency_index == 2 ? IMAGE_WORDS * 5 + IMAGE_WORDS / 2
                                                         : IMAGE_WORDS * 6;
    wire [3:0] normal_complete;
    wire [ADDR_WIDTH - 1:0] loader_wr_addr;
    assign image_complete = fire_loading ? 4'hf : normal_complete;
    assign app_wr_addr =
               loader_wr_addr + ((fire_loading && !LOAD_MULTI_EMERGENCY) ? IMAGE_WORDS * 5 : 0);
    reg scan_start;
    reg file_start;
    reg load_start;

    wire scan_busy;
    wire scan_done;
    wire [7:0] scan_error;
    wire [7:0] sectors_per_cluster;
    wire [31:0] fat_start_lba;
    wire [31:0] data_start_lba;
    wire [31:0] max_cluster;
    wire [31:0] resource0_cluster, resource1_cluster;
    wire [31:0] resource2_cluster, resource3_cluster;
    wire [31:0] resource0_size, resource1_size;
    wire [31:0] resource2_size, resource3_size;
    wire scan_sector_req;
    wire [31:0] scan_sector_lba;

    wire file_busy;
    wire file_done;
    wire file_valid;
    wire [7:0] file_byte;
    wire [31:0] file_byte_offset;
    wire [7:0] file_error;
    wire file_sector_req;
    wire [31:0] file_sector_lba;
    wire [31:0] selected_cluster;
    wire [31:0] selected_size;

    wire pixel_valid;
    wire [23:0] pixel_rgb;
    assign tap_valid = pixel_valid;
    assign tap_rgb   = pixel_rgb;
    assign tap_image = current_image;
    wire frame_commit;
    wire bmp_done;
    wire [7:0] bmp_error;
    wire load_busy;
    wire load_done;
    wire [7:0] memory_error;

    assign fs_spc     = sectors_per_cluster;
    assign fs_fat     = fat_start_lba;
    assign fs_data    = data_start_lba;
    assign fs_max     = max_cluster;
    assign busy       = state != ST_IDLE;
    assign sector_req = scan_sector_req | (!vf_owner && file_sector_req);
    assign vf_req     = vf_owner && file_sector_req;
    assign vf_lba     = file_sector_lba;
    assign sector_lba = scan_sector_req ? scan_sector_lba : file_sector_lba;

    assign selected_cluster =
               fire_loading ? (LOAD_MULTI_EMERGENCY ? selected_emergency_cluster : fire_cluster)
               : current_image == 2'd0 ? resource0_cluster
               : current_image == 2'd1 ? resource1_cluster
               : current_image == 2'd2 ? resource2_cluster
                                       : resource3_cluster;
    assign selected_size = fire_loading
                               ? (LOAD_MULTI_EMERGENCY ? selected_emergency_size : fire_size)
                           : current_image == 2'd0 ? resource0_size
                           : current_image == 2'd1 ? resource1_size
                           : current_image == 2'd2 ? resource2_size
                                                   : resource3_size;

    fat32_volume_scanner #(
        .SUPPORT_SLOTS(SUPPORT_SLOTS),
        .SCAN_EMERGENCY(LOAD_MULTI_EMERGENCY)
    ) u_volume_scanner (
        .selected_slot(selected_slot),
        .extra_valid(extra_valid),
        .extra_clusters(extra_clusters),
        .extra_sizes(extra_sizes),
        .lost_valid(fs_lost_valid),
        .lost_cluster(fs_lost_cluster),
        .lost_size(fs_lost_size),
        .alarm_valid(fs_alarm_valid),
        .alarm_cluster(fs_alarm_cluster),
        .alarm_size(fs_alarm_size),
        .video_valid(fs_video_valid),
        .video_cluster(fs_video_cluster),
        .video_size(fs_video_size),
        .audio_valid(fs_audio_valid),
        .audio_cluster(fs_audio_cluster),
        .audio_size(fs_audio_size),
        .fire_valid(fire_valid),
        .fire_cluster(fire_cluster),
        .fire_size(fire_size),
        .clk(clk),
        .rst_n(rst_n),
        .scan_start(scan_start),
        .scan_busy(scan_busy),
        .scan_done(scan_done),
        .fs_error(scan_error),
        .partition_lba(),
        .sectors_per_cluster(sectors_per_cluster),
        .fat_start_lba(fat_start_lba),
        .data_start_lba(data_start_lba),
        .max_cluster(max_cluster),
        .resource_valid(resource_valid),
        .resource0_cluster(resource0_cluster),
        .resource1_cluster(resource1_cluster),
        .resource2_cluster(resource2_cluster),
        .resource3_cluster(resource3_cluster),
        .resource0_size(resource0_size),
        .resource1_size(resource1_size),
        .resource2_size(resource2_size),
        .resource3_size(resource3_size),
        .sector_req(scan_sector_req),
        .sector_lba(scan_sector_lba),
        .sector_busy(sector_busy),
        .sector_valid(sector_valid),
        .sector_byte(sector_byte),
        .sector_byte_index(sector_byte_index),
        .sector_done(sector_done),
        .sector_error(sector_error)
    );

    wire raw_valid, raw_done;
    wire [7:0] raw_byte, raw_error;
    wire [31:0] raw_offset;
    assign file_valid       = raw_valid && !vf_owner;
    assign file_done        = raw_done && !vf_owner;
    assign file_byte        = raw_byte;
    assign file_byte_offset = raw_offset;
    assign file_error       = vf_owner ? 8'd0 : raw_error;
    assign vf_valid         = raw_valid && vf_owner;
    assign vf_done          = raw_done && vf_owner;
    assign vf_byte          = raw_byte;
    assign vf_offset        = raw_offset;
    assign vf_error         = raw_error;
    // Reacquiring the shared walker after warm ingest starts a fresh video
    // context. The loader emits vf_start two clocks after this ownership edge.
    reg vf_owner_q;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            vf_owner_q <= 0;
        else
            vf_owner_q <= vf_owner;
    wire file_context_rst_n = rst_n && !(vf_owner && !vf_owner_q);
    fat32_file_streamer_compact u_file_streamer (
        .clk(clk),
        .rst_n(file_context_rst_n),
        .file_start(file_start || vf_start),
        .first_cluster(vf_owner ? vf_cluster : selected_cluster),
        .file_size(vf_owner ? vf_size : selected_size),
        .sectors_per_cluster(sectors_per_cluster),
        .fat_start_lba(fat_start_lba),
        .data_start_lba(data_start_lba),
        .max_cluster(max_cluster),
        .file_busy(file_busy),
        .file_done(raw_done),
        .file_valid(raw_valid),
        .file_byte(raw_byte),
        .file_byte_offset(raw_offset),
        .fs_error(raw_error),
        .sector_req(file_sector_req),
        .sector_lba(file_sector_lba),
        .sector_busy(vf_owner ? (vf_busy || !vf_allow) : sector_busy),
        .sector_valid(vf_owner ? vf_sector_valid : sector_valid),
        .sector_byte(vf_owner ? vf_sector_byte : sector_byte),
        .sector_byte_index( vf_owner ? vf_sector_index : sector_byte_index),
        .sector_done(vf_owner ? vf_sector_done : sector_done),
        .sector_error(vf_owner ? vf_sector_error : sector_error)
    );

    wire top_down_w;
    bmp24_decoder #(
        .EXPECTED_WIDTH(IMAGE_WIDTH),
        .EXPECTED_HEIGHT(IMAGE_HEIGHT)
    ) u_bmp_decoder (
        .clk(clk),
        .rst_n(rst_n),
        .file_start(file_start),
        .file_size(selected_size),
        .file_valid(file_valid),
        .file_byte(file_byte),
        .file_byte_offset(file_byte_offset),
        .file_end(file_done),
        .upstream_error(file_error),
        .header_accepted(),
        .pixel_valid(pixel_valid),
        .pixel_rgb(pixel_rgb),
        .pixel_x(tap_x),
        .pixel_y(tap_y),
        .frame_commit(frame_commit),
        .bmp_done(bmp_done),
        .bmp_error(bmp_error),
        .top_down(top_down_w),
        .pixel_offset(),
        .row_stride()
    );

    media_frame_loader #(
        .SUPPORT_PACKED16(LOAD_MULTI_EMERGENCY),
        .ADDR_WIDTH(ADDR_WIDTH),
        .IMAGE_WORDS(IMAGE_WORDS),
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .STALL_TIMEOUT(STALL_TIMEOUT)
    ) u_frame_loader (
        .clk(clk),
        .rst_n(rst_n),
        .load_start(load_start),
        .image_index(current_image),
        .packed_mode(1'b1),
        .packed_base(fire_loading ? 21'd768000 + emergency_index * 21'd153600 : current_image * 21'd153600),
        .pixel_valid(pixel_valid),
        .pixel_rgb(pixel_rgb),
        .top_down(top_down_w),
        .frame_commit(frame_commit),
        .decode_error(bmp_error),
        .load_busy(load_busy),
        .load_done(load_done),
        .image_complete(normal_complete),
        .memory_error(memory_error),
        .controller_init_done(controller_init_done),
        .controller_busy(controller_busy),
        .refresh_active(refresh_active),
        .write_reserved(write_reserved),
        .app_wr_en(app_wr_en),
        .app_wr_addr(loader_wr_addr),
        .app_wr_mask(app_wr_mask),
        .app_wr_data(app_wr_data)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fire_loading        <= 0;
            fire_complete       <= 0;
            fire_error          <= 0;
            emergency_complete  <= 0;
            emergency_index     <= 0;
            state               <= ST_IDLE;
            scan_start          <= 1'b0;
            file_start          <= 1'b0;
            load_start          <= 1'b0;
            done                <= 1'b0;
            ingest_error        <= ERR_NONE;
            ingest_detail_error <= ERR_NONE;
            current_image       <= 2'd0;
        end else begin
            scan_start <= 1'b0;
            file_start <= 1'b0;
            load_start <= 1'b0;
            done       <= 1'b0;

            case (state)
                ST_IDLE:
                    if (start) begin
                        fire_loading        <= 0;
                        fire_complete       <= 0;
                        fire_error          <= 0;
                        emergency_complete  <= 0;
                        emergency_index     <= 0;
                        ingest_error        <= ERR_NONE;
                        ingest_detail_error <= ERR_NONE;
                        current_image       <= 2'd0;
                        scan_start          <= 1'b1;
                        state               <= ST_SCAN;
                    end
                ST_SCAN:
                    if (scan_done) begin
                        if (scan_error != 0) begin
                            ingest_error        <= ERR_SCAN;
                            ingest_detail_error <= scan_error;
                            state               <= ST_FAIL_WAIT;
                        end else begin
                            current_image <= 2'd0;
                            state         <= ST_FILE_START;
                        end
                    end
                ST_FILE_START:
                    if (LOAD_MULTI_EMERGENCY && fire_loading && !selected_emergency_valid) begin
                        if (fire_error == 0)
                            fire_error <= 8'hd1;
                        if (emergency_index == 3) begin
                            done  <= 1;
                            state <= ST_IDLE;
                        end else
                            emergency_index <= emergency_index + 1'b1;
                    end else begin
                        file_start <= 1'b1;
                        load_start <= 1'b1;
                        state      <= ST_FILE;
                    end
                ST_FILE:
                    if (load_done) begin
                        if (fire_loading) begin
                            if (file_error != 0 || bmp_error != 0 || memory_error != 0) begin
                                fire_error <= file_error != 0  ? file_error
                                              : bmp_error != 0 ? bmp_error
                                                               : memory_error;
                                state      <= LOAD_MULTI_EMERGENCY ? 3'd5 : ST_FAIL_WAIT;
                            end else if (LOAD_MULTI_EMERGENCY) begin
                                emergency_complete[emergency_index] <= 1;
                                if (emergency_index == 0)
                                    fire_complete <= 1;
                                state <= 3'd5;
                            end else begin
                                fire_complete <= 1;
                                done          <= 1;
                                state         <= ST_IDLE;
                            end
                        end else if (file_error != 0) begin
                            ingest_error        <= ERR_FILE;
                            ingest_detail_error <= file_error;
                            state               <= ST_FAIL_WAIT;
                        end else if (bmp_error != 0) begin
                            ingest_error        <= ERR_BMP;
                            ingest_detail_error <= bmp_error;
                            state               <= ST_FAIL_WAIT;
                        end else if (memory_error != 0) begin
                            ingest_error        <= ERR_MEMORY;
                            ingest_detail_error <= memory_error;
                            state               <= ST_FAIL_WAIT;
                        end else if (current_image == 2'd3) begin
                            if (LOAD_MULTI_EMERGENCY || (LOAD_FIRE && fire_valid)) begin
                                fire_loading  <= 1;
                                current_image <= 0;
                                state         <= ST_FILE_START;
                            end else begin
                                if (LOAD_FIRE)
                                    fire_error <= 8'hd1;
                                done  <= 1;
                                state <= ST_IDLE;
                            end
                        end else begin
                            current_image <= current_image + 1'b1;
                            state         <= ST_FILE_START;
                        end
                    end
                3'd5:
                    if (!file_busy && !load_busy) begin
                        if (emergency_index == 3) begin
                            done  <= 1;
                            state <= ST_IDLE;
                        end else begin
                            emergency_index <= emergency_index + 1'b1;
                            state           <= ST_FILE_START;
                        end
                    end
                ST_FAIL_WAIT:
                    if (!scan_busy && !file_busy && !load_busy) begin
                        done  <= 1'b1;
                        state <= ST_IDLE;
                    end
                default:
                    state <= ST_IDLE;
            endcase
        end
    end
endmodule
