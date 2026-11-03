// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：解析无压缩24位BMP文件头和像素行，生成用于SDRAM缓存的像素。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// 设计约定：
// 格式约定：按BMP文件头和行跨度解释字节序，像素输出服从下游ready/valid握手。

module bmp24_decoder #(
    parameter integer ALLOW_2X_SOURCE   = 1,
    parameter integer EXPECTED_WIDTH  = 640,
    parameter integer EXPECTED_HEIGHT = 480
)(
    input wire        clk,
    input wire        rst_n,
    input wire        file_start,
    input wire [31:0] file_size,
    input wire        file_valid,
    input wire [7:0]  file_byte,
    input wire [31:0] file_byte_offset,
    input wire        file_end,
    input wire [7:0]  upstream_error,
    output reg        header_accepted,
    output reg        pixel_valid,
    output reg [23:0] pixel_rgb,
    output reg [15:0] pixel_x,
    output reg [15:0] pixel_y,
    output reg        frame_commit,
    output reg        bmp_done,
    output reg [7:0]  bmp_error,
    output reg        top_down,
    output reg [31:0] pixel_offset,
    output reg [31:0] row_stride
);
    localparam ERR_NONE        = 8'h00;
    localparam ERR_SIGNATURE   = 8'h31;
    localparam ERR_DIMENSIONS  = 8'h32;
    localparam ERR_PLANES      = 8'h33;
    localparam ERR_BPP         = 8'h34;
    localparam ERR_COMPRESSION = 8'h35;
    localparam ERR_OFFSET      = 8'h36;
    localparam ERR_TRUNCATED   = 8'h37;
    localparam ERR_UPSTREAM    = 8'h38;

    reg [7:0] header[0:53];
    reg decode_enabled;
    reg scale2;
    wire [31:0] source_width  = scale2 ? EXPECTED_WIDTH * 2 : EXPECTED_WIDTH;
    wire [31:0] source_height = scale2 ? EXPECTED_HEIGHT * 2 : EXPECTED_HEIGHT;
    reg [$clog2(((EXPECTED_WIDTH * 6 + 3) / 4) * 4 + 1) - 1:0] byte_in_row;
    reg [$clog2(EXPECTED_HEIGHT * 2 + 1) - 1:0] physical_row;
    reg [$clog2(EXPECTED_WIDTH * EXPECTED_HEIGHT + 1) - 1:0] pixels_received;
    reg [1:0] channel_phase;
    reg [7:0] blue_hold;
    reg [7:0] green_hold;
    reg [$clog2(EXPECTED_WIDTH * 2 + 1) - 1:0] x_count;

    function [15:0] le16;
        input integer offset;
        begin
            le16 = {header[offset + 1], header[offset]};
        end
    endfunction

    function [31:0] le32;
        input integer offset;
        begin
            le32 = {header[offset + 3], header[offset + 2], header[offset + 1], header[offset]};
        end
    endfunction

    task validate_header;
        reg signed [31:0] parsed_height;
        reg [31:0] absolute_height;
        reg [31:0] parsed_offset;
        reg [31:0] parsed_stride;
        reg [31:0] required_end;
        begin
            parsed_height   = le32(22);
            absolute_height = parsed_height[31] ? (~parsed_height + 1'b1) : parsed_height;
            parsed_offset   = le32(10);
            parsed_stride   = le32(18) == EXPECTED_WIDTH * 2 ? ((EXPECTED_WIDTH * 6 + 3) / 4) * 4
                                                             : ((EXPECTED_WIDTH * 3 + 3) / 4) * 4;
            required_end    = parsed_offset +
                              (le32(18) == EXPECTED_WIDTH * 2
                                      ? (((EXPECTED_WIDTH * 6 + 3) / 4) * 4) * (EXPECTED_HEIGHT * 2)
                                      : (((EXPECTED_WIDTH * 3 + 3) / 4) * 4) * EXPECTED_HEIGHT);
            if (header[0] != "B" || header[1] != "M") begin
                bmp_error      <= ERR_SIGNATURE;
                scale2         <= 0;
                decode_enabled <= 1'b0;
            end else if (!((le32(18) == EXPECTED_WIDTH && absolute_height == EXPECTED_HEIGHT) ||
                             (ALLOW_2X_SOURCE && le32(18) == EXPECTED_WIDTH * 2 &&
                                 absolute_height == EXPECTED_HEIGHT * 2)) ||
                         le32(14) < 40) begin
                bmp_error      <= ERR_DIMENSIONS;
                scale2         <= 0;
                decode_enabled <= 1'b0;
            end else if (le16(26) != 1) begin
                bmp_error      <= ERR_PLANES;
                scale2         <= 0;
                decode_enabled <= 1'b0;
            end else if (le16(28) != 24) begin
                bmp_error      <= ERR_BPP;
                scale2         <= 0;
                decode_enabled <= 1'b0;
            end else if (le32(30) != 0) begin
                bmp_error      <= ERR_COMPRESSION;
                scale2         <= 0;
                decode_enabled <= 1'b0;
            end else if (parsed_offset < 54 || parsed_offset >= file_size) begin
                bmp_error      <= ERR_OFFSET;
                scale2         <= 0;
                decode_enabled <= 1'b0;
            end else if (required_end < parsed_offset || required_end > file_size ||
                         le32(2) < required_end || le32(2) > file_size) begin
                bmp_error      <= ERR_TRUNCATED;
                scale2         <= 0;
                decode_enabled <= 1'b0;
            end else begin
                scale2          <= le32(18) == EXPECTED_WIDTH * 2;
                header_accepted <= 1'b1;
                decode_enabled  <= 1'b1;
                top_down        <= parsed_height[31];
                pixel_offset    <= parsed_offset;
                row_stride      <= parsed_stride;
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            header_accepted <= 1'b0;
            pixel_valid     <= 1'b0;
            pixel_rgb       <= 24'd0;
            pixel_x         <= 16'd0;
            pixel_y         <= 16'd0;
            frame_commit    <= 1'b0;
            bmp_done        <= 1'b0;
            bmp_error       <= ERR_NONE;
            top_down        <= 1'b0;
            pixel_offset    <= 32'd0;
            row_stride      <= 32'd0;
            scale2          <= 0;
            decode_enabled  <= 1'b0;
            byte_in_row     <= 32'd0;
            physical_row    <= 32'd0;
            pixels_received <= 32'd0;
            channel_phase   <= 2'd0;
            blue_hold       <= 8'd0;
            green_hold      <= 8'd0;
            x_count         <= 16'd0;
        end else begin
            pixel_valid  <= 1'b0;
            frame_commit <= 1'b0;
            bmp_done     <= 1'b0;

            if (file_start) begin
                header_accepted <= 1'b0;
                bmp_error       <= ERR_NONE;
                top_down        <= 1'b0;
                pixel_offset    <= 32'd0;
                row_stride      <= 32'd0;
                scale2          <= 0;
                decode_enabled  <= 1'b0;
                byte_in_row     <= 32'd0;
                physical_row    <= 32'd0;
                pixels_received <= 32'd0;
                channel_phase   <= 2'd0;
                x_count         <= 16'd0;
            end

            if (file_valid && file_byte_offset < 54)
                header[file_byte_offset] <= file_byte;

            if (file_valid && file_byte_offset == 53)
                validate_header();

            if (file_valid && decode_enabled && file_byte_offset >= pixel_offset &&
                physical_row < source_height) begin
                if (byte_in_row < source_width * 3) begin
                    case (channel_phase)
                        2'd0: begin
                            blue_hold     <= file_byte;
                            channel_phase <= 2'd1;
                        end
                        2'd1: begin
                            green_hold    <= file_byte;
                            channel_phase <= 2'd2;
                        end
                        default: begin
                            pixel_valid <= !scale2 || (!x_count[0] && !physical_row[0]);
                            pixel_rgb   <= {file_byte, green_hold, blue_hold};
                            pixel_x     <= scale2 ? x_count >> 1 : x_count;
                            pixel_y <=
                                top_down
                                    ? (scale2 ? {{(16 - $clog2(EXPECTED_HEIGHT * 2 + 1)){1'b0}},
                                                    physical_row} >>
                                                    1
                                              : {{(16 - $clog2(EXPECTED_HEIGHT * 2 + 1)){1'b0}},
                                                    physical_row})
                                    : EXPECTED_HEIGHT - 1 -
                                          (scale2 ? {{(16 - $clog2(EXPECTED_HEIGHT * 2 + 1)){1'b0}},
                                                        physical_row} >>
                                                        1
                                                  : {{(16 - $clog2(EXPECTED_HEIGHT * 2 + 1)){1'b0}},
                                                        physical_row});
                            if (!scale2 || (!x_count[0] && !physical_row[0]))
                                pixels_received <= pixels_received + 1'b1;
                            x_count       <= x_count + 1'b1;
                            channel_phase <= 2'd0;
                        end
                    endcase
                end

                if (byte_in_row == row_stride - 1'b1) begin
                    byte_in_row   <= 32'd0;
                    physical_row  <= physical_row + 1'b1;
                    channel_phase <= 2'd0;
                    x_count       <= 16'd0;
                end else begin
                    byte_in_row <= byte_in_row + 1'b1;
                end
            end

            if (file_end) begin
                bmp_done       <= 1'b1;
                scale2         <= 0;
                decode_enabled <= 1'b0;
                if (upstream_error != 0) begin
                    bmp_error <= ERR_UPSTREAM;
                end else if (bmp_error == ERR_NONE && header_accepted &&
                             pixels_received == EXPECTED_WIDTH * EXPECTED_HEIGHT) begin
                    frame_commit <= 1'b1;
                end else if (bmp_error == ERR_NONE) begin
                    bmp_error <= ERR_TRUNCATED;
                end
            end
        end
    end
endmodule
