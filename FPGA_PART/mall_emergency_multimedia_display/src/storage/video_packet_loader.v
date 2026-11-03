// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：检查VIDEO.BIN目录、大小、文件头和包CRC，循环输出图像/音频包。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
`include "src/video/video_media_layout.vh"
// FAT file loops indefinitely. Backpressure is applied only BETWEEN complete
// sectors, never in a live SD SPI transfer. Each audio/video packet has a CRC.
module video_packet_loader
    #(parameter integer SPI_DIV = 1, FILE_BYTES = `CLIP_BYTES, FRAMES = `CLIP_FRAMES,
        parameter [31:0] HEADER_CRC = `CLIP_HEADER_CRC)
    (input wire clk, rst_n, controller_ready, allow_read, frame_accept,
        output reg word_valid,
        output reg [31:0] word_data,
        input wire word_ready,
        output reg frame_pending,
        output reg [7:0] error,
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
    reg [3:0] state;
    reg init_start, scan_start, file_start;
    wire init_done, card_ready;
    wire [7:0] init_error;
    wire [31:0] first_cluster, file_size;
    wire [3:0] resource_valid;
    wire scan_done;
    wire [7:0] scan_error, spc;
    wire [31:0] fat, data, maxc;
    wire scan_req, file_req;
    wire [31:0] scan_lba, file_lba;
    wire sb, sv, sd;
    wire [7:0] sbyte, se;
    wire [8:0] si;
    wire rr, rb, rv, rd;
    wire [31:0] rl;
    wire [7:0] rbyte, re;
    wire [8:0] ri;
    wire fv, fd;
    wire [7:0] fb, fe;
    wire [31:0] fo;
    reg [23:0] accum;
    reg [31:0] crc, header_crc, expected_crc;
    reg [16:0] frame_offset;
    reg [7:0] file_frame;
    function [31:0] crc8;
        input [31:0] c;
        input [7:0] b;
        integer i;
        reg [31:0] v;
        begin
            v = c ^ {24'd0, b};
            for (i = 0; i < 8; i = i + 1)
                v = v[0] ? (v >> 1) ^ 32'hedb88320 : v >> 1;
            crc8 = v;
        end
    endfunction
    assign sector_req    = rr;
    assign sector_lba    = rl;
    assign rb            = sector_busy;
    assign rv            = sector_valid;
    assign rd            = sector_done;
    assign rbyte         = sector_byte;
    assign ri            = sector_byte_index;
    assign re            = sector_error;
    assign first_cluster = directory_cluster;
    assign file_size     = directory_size;
    assign spc           = directory_spc;
    assign fat           = directory_fat;
    assign data          = directory_data;
    assign maxc          = directory_max;
    assign rr            = 1'b0;
    assign rl            = 32'd0;
    assign sb            = rb;
    assign sv            = rv;
    assign sd            = rd;
    assign sbyte         = rbyte;
    assign si            = ri;
    assign se            = re;

    assign vf_allow = allow_read && !frame_pending && error == 0;
    assign vf_start = file_start;
    assign fv       = vf_valid;
    assign fd       = vf_done;
    assign fb       = vf_byte;
    assign fe       = vf_error;
    assign fo       = vf_offset;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= 0;
            init_start    <= 0;
            scan_start    <= 0;
            file_start    <= 0;
            word_valid    <= 0;
            word_data     <= 0;
            frame_pending <= 0;
            error         <= 0;
            accum         <= 0;
            crc           <= 32'hffffffff;
            header_crc    <= 32'hffffffff;
            expected_crc  <= 0;
            frame_offset  <= 0;
            file_frame    <= 0;
        end else begin
            init_start <= 0;
            scan_start <= 0;
            file_start <= 0;
            word_valid <= 0;
            if (frame_accept)
                frame_pending <= 0;
            case (state)
                0:
                    if (controller_ready && directory_ready) begin
                        if (!directory_valid) begin
                            error <= 8'ha2;
                            state <= 15;
                        end else if (file_size != FILE_BYTES) begin
                            error <= 8'ha3;
                            state <= 15;
                        end else
                            state <= 4;
                    end
                4:
                    if (!frame_pending) begin
                        file_start   <= 1;
                        state        <= 5;
                        crc          <= 32'hffffffff;
                        header_crc   <= 32'hffffffff;
                        frame_offset <= 0;
                        file_frame   <= 0;
                    end
                5: begin
                    if (fv) begin
                        if (fo < 512) begin
                            header_crc <= crc8(header_crc, fb);
                            if (fo == 511 && ~crc8(header_crc, fb) != HEADER_CRC) begin
                                error <= 8'ha7;
                                state <= 15;
                            end
                        end else begin
                            case (frame_offset[1:0])
                                0:
                                    accum[7:0] <= fb;
                                1:
                                    accum[15:8] <= fb;
                                2:
                                    accum[23:16] <= fb;
                                3: begin
                                    word_valid <= 1;
                                    word_data  <= {fb, accum};
                                end
                            endcase
                            if (frame_offset < 124800)
                                crc <= crc8(crc, fb);
                            case (frame_offset)
                                124800:
                                    expected_crc[7:0] <= fb;
                                124801:
                                    expected_crc[15:8] <= fb;
                                124802:
                                    expected_crc[23:16] <= fb;
                                124803:
                                    expected_crc[31:24] <= fb;
                            endcase
                            if (frame_offset == `CLIP_FRAME_BYTES - 1) begin
                                if (~crc != expected_crc) begin
                                    error <= 8'ha5;
                                    state <= 15;
                                end else begin
                                    frame_pending <= 1;
                                    frame_offset  <= 0;
                                    file_frame    <= file_frame + 1'b1;
                                    crc           <= 32'hffffffff;
                                end
                            end else
                                frame_offset <= frame_offset + 1'b1;
                        end
                    end
                    if (fd) begin
                        if (fe != 0) begin
                            error <= fe;
                            state <= 15;
                        end else if (file_frame != FRAMES) begin
                            error <= 8'ha4;
                            state <= 15;
                        end else
                            state <= 4;
                    end
                end
                default:
                    state <= state;
            endcase
            if (word_valid && !word_ready) begin
                error <= 8'ha6;
                state <= 15;
            end
        end
    end
endmodule
