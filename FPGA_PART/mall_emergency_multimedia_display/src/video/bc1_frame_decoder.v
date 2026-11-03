// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：解码BC1块为RGB565像素，支持输入与输出背压。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Opaque 4x4 BC1 tiles, in row-major tile order. Four scanlines are transposed
// through block RAM, preserving every 640x360 source pixel. Output RGB565 pairs.
// 设计约定：
// 解码约定：BC1块的颜色端点与选择索引按现有位序展开，不将任意MP4当作输入。

module bc1_frame_decoder (
    input wire         clk,
                       rst_n,
                       start,
    input wire         byte_valid,
    input wire [7:0]   byte_data,
    output wire        byte_ready,
    output wire        word_valid,
    output wire [31:0] word_data,
    input wire         word_ready,
    output reg         busy,
                       done,
    output reg [7:0]   error
);
    localparam IDLE = 0, TOP = 1, BLOCK = 2, PREP = 3, STORE = 4, FETCH = 5, OUT = 6, BOTTOM = 7,
               FINISH = 8, FETCH_HI = 9;
    reg [3:0] state;
    reg [2:0] byte_number;
    reg [3:0] store_step;
    reg [7:0] tile_x;
    reg [6:0] tile_y;
    reg [15:0] colors[0:3];
    reg [31:0] selectors;
    reg [7:0] low;
    reg [10:0] flush_address;
    reg [15:0] pixel_low;
    wire [15:0] pixel_read;
    wire [15:0] bank_q[0:4];
    reg [2:0] read_bank;
    reg [14:0] border_count;
    reg [17:0] consumed;
    reg [23:0] watchdog;
    wire take                   = byte_valid && byte_ready;
    wire [4:0] shift          = {store_step, 1'b0};
    wire [1:0] i0             = (selectors >> shift) & 3;
    wire [1:0] i1             = (selectors >> (shift + 6'd2)) & 3;
    wire [11:0] store_address = store_step[3:2] * 12'd640 + {tile_x, 2'b00} + store_step[1:0];
    wire [11:0] fetch_address = {flush_address, 1'b0} + (state == FETCH_HI);
    assign byte_ready           = state == BLOCK;
    assign word_valid           = state == TOP || state == BOTTOM || state == OUT;
    assign word_data            = state == OUT ? {pixel_read, pixel_low} : 32'd0;
    wire sent                   = word_valid && word_ready;
    function [15:0] mix;
        input [15:0] a, b;
        input choose;
        reg [7:0] r, g, bl;
        begin
            if (!choose) begin
                r  = (2 * {3'd0, a[15:11]} + {3'd0, b[15:11]}) / 3;
                g  = (2 * {2'd0, a[10:5]} + {2'd0, b[10:5]}) / 3;
                bl = (2 * {3'd0, a[4:0]} + {3'd0, b[4:0]}) / 3;
            end else begin
                r  = ({3'd0, a[15:11]} + 2 * {3'd0, b[15:11]}) / 3;
                g  = ({2'd0, a[10:5]} + 2 * {2'd0, b[10:5]}) / 3;
                bl = ({3'd0, a[4:0]} + 2 * {3'd0, b[4:0]}) / 3;
            end
            mix = {r[4:0], g[5:0], bl[4:0]};
        end
    endfunction
    genvar bi;
    generate
        for (bi = 0; bi < 5; bi = bi + 1) begin : g_lines
            reg [15:0] memory[0:511];
            reg [15:0] q;
            always @(posedge clk) begin
                if (state == STORE && store_address[11:9] == bi)
                    memory[store_address[8:0]] <= colors[i0];
                if (state == FETCH || state == FETCH_HI)
                    q <= memory[fetch_address[8:0]];
            end
            assign bank_q[bi] = q;
        end
    endgenerate
    always @(posedge clk)
        if (state == FETCH || state == FETCH_HI)
            read_bank <= fetch_address[11:9];
    assign pixel_read = bank_q[read_bank];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            byte_number   <= 0;
            store_step    <= 0;
            tile_x        <= 0;
            tile_y        <= 0;
            selectors     <= 0;
            low           <= 0;
            flush_address <= 0;
            border_count  <= 0;
            consumed      <= 0;
            watchdog      <= 0;
            busy          <= 0;
            done          <= 0;
            error         <= 0;
            colors[0]     <= 0;
            colors[1]     <= 0;
            colors[2]     <= 0;
            colors[3]     <= 0;
        end else begin
            done <= 0;
            if (busy && !take && !sent && state != STORE && state != PREP && state != FETCH)
                watchdog <= watchdog + 1'b1;
            else
                watchdog <= 0;
            if (take)
                consumed <= consumed + 1'b1;
            case (state)
                IDLE:
                    if (start) begin
                        state        <= TOP;
                        busy         <= 1;
                        error        <= 0;
                        consumed     <= 0;
                        border_count <= 0;
                        tile_x       <= 0;
                        tile_y       <= 0;
                        byte_number  <= 0;
                    end
                TOP:
                    if (sent) begin
                        if (border_count == 19199) begin
                            border_count <= 0;
                            state        <= BLOCK;
                        end else
                            border_count <= border_count + 1'b1;
                    end
                BLOCK:
                    if (take) begin
                        byte_number <= byte_number + 1'b1;
                        case (byte_number)
                            0, 2:
                                low <= byte_data;
                            1:
                                colors[0] <= {byte_data, low};
                            3:
                                colors[1] <= {byte_data, low};
                            4:
                                selectors[7:0] <= byte_data;
                            5:
                                selectors[15:8] <= byte_data;
                            6:
                                selectors[23:16] <= byte_data;
                            7: begin
                                selectors[31:24] <= byte_data;
                                state              <= PREP;
                            end
                        endcase
                    end
                PREP: begin
                    colors[2]  <= mix(colors[0], colors[1], 0);
                    colors[3]  <= mix(colors[0], colors[1], 1);
                    store_step <= 0;
                    state      <= STORE;
                end
                STORE:
                    if (store_step == 15) begin
                        if (tile_x == 159) begin
                            flush_address <= 0;
                            tile_x        <= 0;
                            state         <= FETCH;
                        end else begin
                            tile_x <= tile_x + 1'b1;
                            state  <= BLOCK;
                        end
                    end else
                        store_step <= store_step + 1'b1;
                FETCH:
                    state <= FETCH_HI;
                FETCH_HI: begin
                    pixel_low <= pixel_read;
                    state     <= OUT;
                end
                OUT:
                    if (sent) begin
                        if (flush_address == 1279) begin
                            if (tile_y == 89) begin
                                if (consumed != 115200) begin
                                    error <= 8'hb4;
                                    busy  <= 0;
                                    state <= IDLE;
                                end else begin
                                    border_count <= 0;
                                    state        <= BOTTOM;
                                end
                            end else begin
                                tile_y <= tile_y + 1'b1;
                                state  <= BLOCK;
                            end
                        end else begin
                            flush_address <= flush_address + 1'b1;
                            state         <= FETCH;
                        end
                    end
                BOTTOM:
                    if (sent) begin
                        if (border_count == 19199)
                            state <= FINISH;
                        else
                            border_count <= border_count + 1'b1;
                    end
                FINISH: begin
                    done  <= 1;
                    busy  <= 0;
                    state <= IDLE;
                end
                default: begin
                    error <= 8'hbf;
                    busy  <= 0;
                    state <= IDLE;
                end
            endcase
            if (busy && watchdog == 24'hffffff) begin
                error <= 8'hb5;
                busy  <= 0;
                state <= IDLE;
            end
        end
    end
endmodule
