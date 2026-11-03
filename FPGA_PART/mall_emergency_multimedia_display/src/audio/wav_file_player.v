// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：读取标准48kHz/16位/单声道WAV，经异步FIFO送入像素域音频路径。
// 时钟：mem_clk、pix_clk。
// 复位：mem_rst_n（低有效异步复位）；pix_rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Read MUSIC.WAV through FAT32 after image ingest has released the SD port.
// Canonical 44-byte RIFF PCM, 48kHz, 16-bit mono/stereo. Other layouts reject
// with 0x75 and leave the original synthesized tone available as fallback.
// 设计约定：
// 格式约定：文件为48kHz、16位、单声道PCM WAV，媒体读时钟与像素音频时钟通过FIFO隔离。

module wav_file_player #(
    parameter integer USE_EXTERNAL_DIRECTORY = 0,
    parameter integer SUPPORT_PAUSE        = 0,
    parameter integer FIFO_AW              = 11,
    parameter integer MONO_ONLY            = 0,
    parameter integer COMPACT_LOOP_CHECK   = 0
)(
    input wire               pause_playback,
    input wire               directory_valid,
    input wire [7:0]         directory_spc,
    input wire [31:0]        directory_fat,
                             directory_data,
                             directory_max,
                             directory_cluster,
                             directory_size,
    input wire               mem_clk,
                             mem_rst_n,
                             enable,
    output wire              sector_req,
    output wire [31:0]       sector_lba,
    input wire               sector_busy,
                             sector_valid,
                             sector_done,
    input wire [7:0]         sector_byte,
                             sector_error,
    input wire [8:0]         sector_byte_index,
    input wire               pix_clk,
                             pix_rst_n,
    output wire              active,
    output reg               sample_valid,
    input wire               sample_ready,
    output reg signed [15:0] sample_left,
                             sample_right,
    output reg [7:0]         error_code
);
    reg [2:0] state;
    reg scan_start, file_start;
    wire scan_done, scan_busy, file_busy, file_done;
    wire [7:0] scan_error, file_error, spc;
    wire [31:0] fat, data, max_cluster, cluster, size;
    wire [3:0] resources;
    wire scan_req, file_req;
    wire [31:0] scan_lba, file_lba;
    wire fv;
    wire [7:0] fb;
    wire [31:0] fo;
    reg [7:0] header[0:43];
    reg header_ok, stereo;
    reg [31:0] data_bytes;
    reg [1:0] byte_phase;
    reg [7:0] lo;
    reg [15:0] left_hold;
    reg fifo_push;
    reg [31:0] fifo_input;
    localparam integer FIFO_DW = MONO_ONLY ? 16 : 32;
    wire fifo_full, fifo_empty;
    wire [FIFO_AW:0] level;
    wire [FIFO_DW - 1:0] fifo_output;
    reg enabled_q;
    assign sector_req = scan_req | file_req;
    assign sector_lba = scan_req ? scan_lba : file_lba;
    generate
        if (USE_EXTERNAL_DIRECTORY) begin : g_shared_directory
            assign spc         = directory_spc;
            assign fat         = directory_fat;
            assign data        = directory_data;
            assign max_cluster = directory_max;
            assign cluster     = directory_cluster;
            assign size        = directory_size;
            assign resources   = {3'b0, directory_valid};
            assign scan_busy   = 0;
            assign scan_done   = 0;
            assign scan_error  = 0;
            assign scan_req    = 0;
            assign scan_lba    = 0;
        end else begin : g_private_directory
            fat32_volume_scanner #(
                .AUDIO_SCAN(1)
            ) u_audio_scan (
                .clk(mem_clk),
                .rst_n(mem_rst_n),
                .scan_start(scan_start),
                .scan_busy(scan_busy),
                .scan_done(scan_done),
                .fs_error(scan_error),
                .partition_lba(),
                .sectors_per_cluster(spc),
                .fat_start_lba(fat),
                .data_start_lba(data),
                .max_cluster(max_cluster),
                .resource_valid(resources),
                .resource0_cluster(cluster),
                .resource0_size(size),
                .resource1_cluster(),
                .resource2_cluster(),
                .resource3_cluster(),
                .resource1_size(),
                .resource2_size(),
                .resource3_size(),
                .sector_req(scan_req),
                .sector_lba(scan_lba),
                .sector_busy(sector_busy),
                .sector_valid(sector_valid),
                .sector_byte(sector_byte),
                .sector_byte_index(sector_byte_index),
                .sector_done(sector_done),
                .sector_error(sector_error)
            );
        end
    endgenerate
    fat32_file_streamer_compact u_audio_stream (
        .clk(mem_clk),
        .rst_n(mem_rst_n),
        .file_start(file_start),
        .first_cluster(cluster),
        .file_size(size),
        .sectors_per_cluster(spc),
        .fat_start_lba(fat),
        .data_start_lba(data),
        .max_cluster(max_cluster),
        .file_busy(file_busy),
        .file_done(file_done),
        .file_valid(fv),
        .file_byte(fb),
        .file_byte_offset(fo),
        .fs_error(file_error),
        .sector_req(file_req),
        .sector_lba(file_lba),
        .sector_busy(sector_busy || level > ((1 << FIFO_AW) - 298)),
        .sector_valid(sector_valid),
        .sector_byte(sector_byte),
        .sector_byte_index(sector_byte_index),
        .sector_done(sector_done),
        .sector_error(sector_error)
    );
    function [15:0] le16;
        input integer p;
        begin
            le16 = {header[p + 1], header[p]};
        end
    endfunction
    function [31:0] le32;
        input integer p;
        begin
            le32 = {header[p + 3], header[p + 2], header[p + 1], header[p]};
        end
    endfunction
    reg compact_bad;
    reg [23:0] compact_length;
    function bad_mono_header;
        input [5:0] offset;
        input [7:0] value;
        begin
            case (offset)
                0:
                    bad_mono_header = value != "R";
                1:
                    bad_mono_header = value != "I";
                2, 3:
                    bad_mono_header = value != "F";
                8:
                    bad_mono_header = value != "W";
                9:
                    bad_mono_header = value != "A";
                10:
                    bad_mono_header = value != "V";
                11:
                    bad_mono_header = value != "E";
                12:
                    bad_mono_header = value != "f";
                13:
                    bad_mono_header = value != "m";
                14:
                    bad_mono_header = value != "t";
                15:
                    bad_mono_header = value != " ";
                16, 34:
                    bad_mono_header = value != 16;
                20, 22:
                    bad_mono_header = value != 1;
                24:
                    bad_mono_header = value != 8'h80;
                25:
                    bad_mono_header = value != 8'hbb;
                32:
                    bad_mono_header = value != 2;
                36:
                    bad_mono_header = value != "d";
                37:
                    bad_mono_header = value != "a";
                38:
                    bad_mono_header = value != "t";
                39:
                    bad_mono_header = value != "a";
                17, 18, 19, 21, 23, 26, 27, 33, 35:
                    bad_mono_header = value != 0;
                default:
                    bad_mono_header = 0;
            endcase
        end
    endfunction
    wire [31:0] incoming_size =
                      MONO_ONLY ? {fb, compact_length} : {fb, header[42], header[41], header[40]};
    always @(posedge mem_clk or negedge mem_rst_n)
        if (!mem_rst_n) begin
            state          <= 0;
            scan_start     <= 0;
            file_start     <= 0;
            error_code     <= 0;
            compact_bad    <= 0;
            compact_length <= 0;
            header_ok      <= 0;
            stereo         <= 0;
            data_bytes     <= 0;
            byte_phase     <= 0;
            lo             <= 0;
            left_hold      <= 0;
            fifo_push      <= 0;
            fifo_input     <= 0;
            enabled_q      <= 0;
        end else begin
            scan_start <= 0;
            file_start <= 0;
            fifo_push  <= 0;
            enabled_q  <= enable;
            case (state)
                0:
                    if (enable && !enabled_q) begin
                        if (USE_EXTERNAL_DIRECTORY) begin
                            if (directory_valid) begin
                                file_start <= 1;
                                state      <= 2;
                            end else
                                state <= 5;
                        end else begin
                            scan_start <= 1;
                            state      <= 1;
                        end
                    end
                1:
                    if (scan_done) begin
                        if (scan_error != 0) begin
                            state      <= 5;
                            error_code <= scan_error == 8'h22 ? 8'd0 : scan_error;
                        end else begin
                            file_start <= 1;
                            state      <= 2;
                        end
                    end
                2:
                    if (file_done) begin
                        if (file_error != 0) begin
                            error_code <= file_error;
                            header_ok  <= 0;
                            state      <= 5;
                        end else
                            state <= 3;
                    end
                3:
                    if (level <= 1024 && !file_busy) begin
                        file_start <= 1;
                        state      <= 2;
                    end
                default: begin
                end
            endcase
            if (file_start) begin
                byte_phase     <= 0;
                data_bytes     <= 0;
                compact_bad    <= 0;
                compact_length <= 0;
            end
            if (fv && fo < 44) begin
                if (!MONO_ONLY)
                    header[fo] <= fb;
                else begin
                    if (bad_mono_header(fo[5:0], fb))
                        compact_bad <= 1;
                    if (fo == 40)
                        compact_length[7:0] <= fb;
                    if (fo == 41)
                        compact_length[15:8] <= fb;
                    if (fo == 42)
                        compact_length[23:16] <= fb;
                end
            end
            if (fv && fo == 43) begin
                if (MONO_ONLY) begin
                    if (compact_bad || size < 44 || incoming_size == 0 ||
                        incoming_size > size - 44 || incoming_size[0]) begin
                        error_code <= 8'h75;
                        header_ok  <= 0;
                    end else begin
                        header_ok  <= 1;
                        stereo     <= 0;
                        data_bytes <= incoming_size;
                    end
                end else if ({header[0], header[1], header[2], header[3]} != "RIFF" ||
                             {header[8], header[9], header[10], header[11]} != "WAVE" ||
                             {header[12], header[13], header[14], header[15]} != "fmt " ||
                             le32(16) != 16 || le16(20) != 1 ||
                             (le16(22) != 1 && (MONO_ONLY || le16(22) != 2)) || le32(24) != 48000 ||
                             le16(34) != 16 || le16(32) != (le16(22) * 2) ||
                             {header[36], header[37], header[38], header[39]} != "data" ||
                             size < 44 || incoming_size == 0 || incoming_size > size - 44 ||
                             (le16(22) == 1 && incoming_size[0]) ||
                             (le16(22) == 2 && |incoming_size[1:0])) begin
                    error_code <= 8'h75;
                    header_ok  <= 0;
                end else begin
                    header_ok  <= 1;
                    stereo     <= !MONO_ONLY && le16(22) == 2;
                    data_bytes <= incoming_size;
                end
            end
            if (fv && header_ok && fo >= 44 && (fo - 44) < data_bytes) begin
                case (byte_phase)
                    0: begin
                        lo         <= fb;
                        byte_phase <= 1;
                    end
                    1:
                        if (stereo) begin
                            left_hold  <= {fb, lo};
                            byte_phase <= 2;
                        end else begin
                            fifo_input <= {{fb, lo}, {fb, lo}};
                            fifo_push  <= 1;
                            byte_phase <= 0;
                        end
                    2: begin
                        lo         <= fb;
                        byte_phase <= 3;
                    end
                    3: begin
                        fifo_input <= {{fb, lo}, left_hold};
                        fifo_push  <= 1;
                        byte_phase <= 0;
                    end
                endcase
            end
            if (fifo_push && fifo_full) begin
                error_code <= 8'h76;
                header_ok  <= 0;
            end
        end
    reg ok1, ok2;
    reg [24:0] rate;
    reg pending;
    wire tick   = rate >= 25000000 - 48000;
    wire paused = SUPPORT_PAUSE && pause_playback;
    wire pop = tick && ok2 && !paused && !fifo_empty && !pending && (!sample_valid || sample_ready);
    assign active = ok2;
    async_pcm_fifo #(
        .AW(FIFO_AW),
        .DW(FIFO_DW)
    ) u_fifo (
        .wr_clk(mem_clk),
        .wr_rst_n(mem_rst_n),
        .wr_en(fifo_push),
        .wr_data(fifo_input[FIFO_DW - 1:0]),
        .full(fifo_full),
        .wr_level(level),
        .rd_clk(pix_clk),
        .rd_rst_n(pix_rst_n),
        .rd_en(pop),
        .rd_data(fifo_output),
        .empty(fifo_empty)
    );
    always @(posedge pix_clk or negedge pix_rst_n)
        if (!pix_rst_n) begin
            ok1          <= 0;
            ok2          <= 0;
            rate         <= 0;
            pending      <= 0;
            sample_valid <= 0;
            sample_left  <= 0;
            sample_right <= 0;
        end else begin
            ok1 <= header_ok;
            ok2 <= ok1;
            if (!paused)
                rate <= tick ? rate + 48000 - 25000000 : rate + 48000;
            if (sample_valid && sample_ready && !paused)
                sample_valid <= 0;
            pending <= pop;
            if (pending) begin
                sample_left  <= fifo_output[15:0];
                sample_right <= MONO_ONLY ? fifo_output[15:0] : fifo_output[FIFO_DW - 1 -: 16];
                sample_valid <= 1;
            end else if (tick && ok2 && !paused && fifo_empty && (!sample_valid || sample_ready))
            begin
                sample_left  <= 0;
                sample_right <= 0;
                sample_valid <= 1;
            end
        end
endmodule
