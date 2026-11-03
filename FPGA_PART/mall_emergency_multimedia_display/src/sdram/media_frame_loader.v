// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：把解码像素打包为SDRAM突发写，处理流控与地址推进。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

module media_frame_loader #(
    parameter integer ADDR_WIDTH         = 21,
    parameter integer SUPPORT_PACKED16 = 0,
    parameter integer IMAGE_WORDS      = 307200,
    parameter integer IMAGE_WIDTH      = 640,
    parameter integer FIFO_DEPTH       = 512,
    parameter integer BURST_SIZE       = 128,
    parameter integer STALL_TIMEOUT    = 65535
)(
    input wire                    clk,
    input wire                    rst_n,
    input wire                    load_start,
    input wire [1:0]              image_index,
    input wire                    packed_mode,
    input wire [ADDR_WIDTH - 1:0] packed_base,
    input wire                    pixel_valid,
    input wire [23:0]             pixel_rgb,
    input wire                    top_down,
    input wire                    frame_commit,
    input wire [7:0]              decode_error,
    output wire                   load_busy,
    output reg                    load_done,
    output reg [3:0]              image_complete,
    output reg [7:0]              memory_error,
    input wire                    controller_init_done,
    input wire                    controller_busy,
    input wire                    refresh_active,
    output wire                   write_reserved,
    output reg                    app_wr_en,
    output reg [ADDR_WIDTH - 1:0] app_wr_addr,
    output reg [3:0]              app_wr_mask,
    output reg [31:0]             app_wr_data
);
    localparam ERR_NONE          = 8'h00;
    localparam ERR_NOT_ACTIVE    = 8'h41;
    localparam ERR_FIFO_OVERFLOW = 8'h42;
    localparam ERR_PIXEL_COUNT   = 8'h43;
    localparam ERR_DECODE        = 8'h44;
    localparam ERR_SHORT_FRAME   = 8'h45;
    localparam ERR_WRITE_STALL   = 8'h46;

    localparam integer PTR_WIDTH = (FIFO_DEPTH <= 2) ? 1 : $clog2(FIFO_DEPTH);
    localparam [PTR_WIDTH:0] EFFECTIVE_BURST =
                                   (BURST_SIZE < FIFO_DEPTH) ? BURST_SIZE : FIFO_DEPTH;
    localparam [ADDR_WIDTH - 1:0] BANK0_BASE = 0;
    localparam [ADDR_WIDTH - 1:0] BANK1_BASE = IMAGE_WORDS;
    localparam [ADDR_WIDTH - 1:0] BANK2_BASE = IMAGE_WORDS * 2;
    localparam [ADDR_WIDTH - 1:0] BANK3_BASE = IMAGE_WORDS * 3;

    localparam integer COUNT_W = $clog2(IMAGE_WORDS + 1);
    reg active;
    reg active_packed, pair_half;
    reg [15:0] first_half;
    reg [ADDR_WIDTH - 1:0] active_base;
    wire [15:0] rgb565  = {pixel_rgb[23:19], pixel_rgb[15:10], pixel_rgb[7:3]};
    wire input_word_valid = pixel_valid && (!active_packed || pair_half);
    wire [COUNT_W - 1:0] target_words = active_packed ? IMAGE_WORDS / 2 : IMAGE_WORDS;
    wire [15:0] row_words             = active_packed ? IMAGE_WIDTH / 2 : IMAGE_WIDTH;
    reg [1:0] active_image;
    reg commit_seen;
    reg [COUNT_W - 1:0] pixels_received;
    reg [COUNT_W - 1:0] pixels_written;
    reg [$clog2(STALL_TIMEOUT + 1) - 1:0] stall_count;
    reg [31:0] fifo_mem[0:FIFO_DEPTH - 1] /* fehdl force_ram=1, ram_style="bram" */;
    reg [PTR_WIDTH - 1:0] wr_ptr;
    reg [PTR_WIDTH - 1:0] rd_ptr;
    reg [PTR_WIDTH:0] fifo_count;
    reg burst_active;
    assign write_reserved = burst_active || app_wr_en;
    reg [PTR_WIDTH:0] burst_remaining;
    wire pop_allowed;
    wire push_allowed;
    wire start_burst;
    wire [PTR_WIDTH:0] next_burst_words;

    assign load_busy = active;
    // The inherited controller consumes a continuous App_wr_en burst and
    // requires idle/refresh-safe admission for a NEW burst. Those status
    // outputs are not per-word ready signals: never split an active burst.
    assign start_burst      = active && controller_init_done && !burst_active && !controller_busy &&
                              !refresh_active && fifo_count != 0 &&
                              (fifo_count >= EFFECTIVE_BURST || commit_seen);
    assign next_burst_words = (fifo_count >= EFFECTIVE_BURST) ? EFFECTIVE_BURST : fifo_count;
    assign pop_allowed      = active && controller_init_done && burst_active && fifo_count != 0;
    // Bottom-up BMP files (positive height) emit the bottom row first, each
    // row left-to-right. The write address is therefore mirrored per ROW
    // (display row d takes stream row H-1-d, columns stay in order); a whole
    // stream mirror would also flip columns left-to-right. top_down files
    // (negative height) are already in display order.
    reg [$clog2(IMAGE_WIDTH) - 1:0] stream_col;
    reg [COUNT_W - 1:0] bottom_row_base;
    wire [ADDR_WIDTH - 1:0] write_offset =
                                  top_down ? pixels_written : bottom_row_base + stream_col;
    assign push_allowed = active && input_word_valid && (fifo_count < FIFO_DEPTH || pop_allowed);

    // Synchronous dual-port RAM template. Data has meaning only when the
    // registered app_wr_en is asserted, so the RAM read output needs no
    // asynchronous reset. Keeping the RAM out of the control/reset process
    // avoids a 512x32 LUT mux and leaves routing capacity for the video path.
    always @(posedge clk) begin
        if (push_allowed)
            fifo_mem[wr_ptr] <= active_packed ? {rgb565, first_half} : {8'h00, pixel_rgb};
        if (pop_allowed)
            app_wr_data <= fifo_mem[rd_ptr];
    end

    function [ADDR_WIDTH - 1:0] bank_base;
        input [1:0] index;
        begin
            case (index)
                2'd0:
                    bank_base = BANK0_BASE;
                2'd1:
                    bank_base = BANK1_BASE;
                2'd2:
                    bank_base = BANK2_BASE;
                default:
                    bank_base = BANK3_BASE;
            endcase
        end
    endfunction

    task fail_load;
        input [7:0] code;
        begin
            memory_error    <= code;
            active          <= 1'b0;
            burst_active    <= 1'b0;
            burst_remaining <= 0;
            load_done       <= 1'b1;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active          <= 1'b0;
            active_packed   <= 0;
            active_base     <= 0;
            pair_half       <= 0;
            first_half      <= 0;
            active_image    <= 2'd0;
            commit_seen     <= 1'b0;
            pixels_received <= 32'd0;
            pixels_written  <= 0;
            stream_col      <= 0;
            bottom_row_base <= IMAGE_WORDS - IMAGE_WIDTH;
            stall_count     <= 32'd0;
            wr_ptr          <= {PTR_WIDTH{1'b0}};
            rd_ptr          <= {PTR_WIDTH{1'b0}};
            fifo_count      <= {(PTR_WIDTH + 1){1'b0}};
            burst_active    <= 1'b0;
            burst_remaining <= 0;
            load_done       <= 1'b0;
            image_complete  <= 4'd0;
            memory_error    <= ERR_NONE;
            app_wr_en       <= 1'b0;
            app_wr_addr     <= {ADDR_WIDTH{1'b0}};
            app_wr_mask     <= 4'b0000;
        end else begin
            load_done <= 1'b0;
            app_wr_en <= 1'b0;

            if (load_start && !active) begin
                active          <= 1'b1;
                active_image    <= image_index;
                active_packed   <= SUPPORT_PACKED16 && packed_mode;
                active_base     <= packed_base;
                pair_half       <= 0;
                commit_seen     <= 1'b0;
                pixels_received <= 32'd0;
                pixels_written  <= 0;
                stream_col      <= 0;
                bottom_row_base <= (SUPPORT_PACKED16 && packed_mode)
                                       ? (IMAGE_WORDS - IMAGE_WIDTH) / 2
                                       : IMAGE_WORDS - IMAGE_WIDTH;
                stall_count     <= 32'd0;
                wr_ptr          <= {PTR_WIDTH{1'b0}};
                rd_ptr          <= {PTR_WIDTH{1'b0}};
                fifo_count      <= {(PTR_WIDTH + 1){1'b0}};
                burst_active    <= 1'b0;
                burst_remaining <= 0;
                memory_error    <= ERR_NONE;
                case (image_index)
                    2'd0:
                        image_complete[0] <= 1'b0;
                    2'd1:
                        image_complete[1] <= 1'b0;
                    2'd2:
                        image_complete[2] <= 1'b0;
                    default:
                        image_complete[3] <= 1'b0;
                endcase
            end

            if (active) begin
                if (pixel_valid && active_packed) begin
                    pair_half <= ~pair_half;
                    if (!pair_half)
                        first_half <= rgb565;
                end
                if (decode_error != 0) begin
                    fail_load(ERR_DECODE);
                end else if (input_word_valid && pixels_received >= target_words) begin
                    fail_load(ERR_PIXEL_COUNT);
                end else if (input_word_valid && !push_allowed) begin
                    fail_load(ERR_FIFO_OVERFLOW);
                end else begin
                    if (start_burst) begin
                        burst_active    <= 1'b1;
                        burst_remaining <= next_burst_words;
                    end

                    if (push_allowed) begin
                        wr_ptr          <= wr_ptr + 1'b1;
                        pixels_received <= pixels_received + 1'b1;
                    end

                    if (pop_allowed) begin
                        app_wr_en      <= 1'b1;
                        app_wr_addr    <= (active_packed ? active_base : bank_base(active_image)) +
                                          write_offset[ADDR_WIDTH - 1:0];
                        app_wr_mask    <= 4'b0000;
                        rd_ptr         <= rd_ptr + 1'b1;
                        pixels_written <= pixels_written + 1'b1;
                        if (stream_col == row_words - 1) begin
                            stream_col <= 0;
                            if (bottom_row_base >= row_words)
                                bottom_row_base <= bottom_row_base - row_words;
                        end else
                            stream_col <= stream_col + 1'b1;

                        stall_count <= 32'd0;
                        if (burst_remaining == 1) begin
                            burst_active    <= 1'b0;
                            burst_remaining <= 0;
                        end else begin
                            burst_remaining <= burst_remaining - 1'b1;
                        end
                    end else if (fifo_count != 0 && (commit_seen || fifo_count >= EFFECTIVE_BURST))
                    begin
                        if (stall_count == STALL_TIMEOUT)
                            fail_load(ERR_WRITE_STALL);
                        else
                            stall_count <= stall_count + 1'b1;
                    end else begin
                        stall_count <= 32'd0;
                    end

                    case ({push_allowed, pop_allowed})
                        2'b10:
                            fifo_count <= fifo_count + 1'b1;
                        2'b01:
                            fifo_count <= fifo_count - 1'b1;
                        default:
                            fifo_count <= fifo_count;
                    endcase

                    if (frame_commit)
                        commit_seen <= 1'b1;

                    if (commit_seen && fifo_count == 0 && !pop_allowed && !burst_active) begin
                        if (pixels_received != target_words || pixels_written != target_words ||
                            (active_packed && pair_half)) begin
                            fail_load(ERR_SHORT_FRAME);
                        end else begin
                            case (active_image)
                                2'd0:
                                    image_complete[0] <= 1'b1;
                                2'd1:
                                    image_complete[1] <= 1'b1;
                                2'd2:
                                    image_complete[2] <= 1'b1;
                                default:
                                    image_complete[3] <= 1'b1;
                            endcase
                            active    <= 1'b0;
                            load_done <= 1'b1;
                        end
                    end
                end
            end else if (pixel_valid) begin
                memory_error <= ERR_NOT_ACTIVE;
            end
        end
    end
endmodule
