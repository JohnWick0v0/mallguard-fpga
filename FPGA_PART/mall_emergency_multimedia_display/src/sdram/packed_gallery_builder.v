// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：由缓存图像生成完整分辨率四宫格，按打包像素写入缩略图帧。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Native 2x2 RGB565 box filter. Source pairs arrive in one SDRAM word;
// synchronous row RAM carries horizontal sums into the second source row.
module packed_gallery_builder #(
    parameter integer SUPPORT_ARBITRATION = 0
)(
    input wire        clk,
                      rst_n,
                      start,
                      controller_init_done,
                      controller_busy,
                      refresh_active,
    output wire       busy,
    output reg        done,
    output reg [7:0]  error_code,
    input wire        pause_admission,
    output wire       transaction_active,
    output reg        app_rd_en,
    output reg [20:0] app_rd_addr,
    input wire        sdram_rd_valid,
    input wire [31:0] sdram_rd_data,
    output reg        app_wr_en,
    output reg [20:0] app_wr_addr,
    output wire [3:0] app_wr_mask,
    output reg [31:0] app_wr_data
);
    reg [2:0] state;
    reg [1:0] image;
    reg [7:0] row;
    reg [9:0] issued, returned;
    reg [7:0] burst, gap;
    reg [8:0] col, write_col;
    reg row_half;
    reg [31:0] sums[0:1023] /* fehdl force_ram=1, ram_style="bram" */;
    reg [31:0] sum_q, word_q;
    reg valid_q;
    reg [9:0] col_q;
    reg row_q;
    reg [15:0] pair;
    wire [9:0] column = {1'b0, col} + (image[0] ? 10'd320 : 0);
    wire [8:0] hr = {1'b0, sdram_rd_data[15:11], 3'd0} + {1'b0, sdram_rd_data[31:27], 3'd0};
    wire [8:0] hg = {1'b0, sdram_rd_data[10:5], 2'd0} + {1'b0, sdram_rd_data[26:21], 2'd0};
    wire [8:0] hb = {1'b0, sdram_rd_data[4:0], 3'd0} + {1'b0, sdram_rd_data[20:16], 3'd0};
    wire [9:0] sr = {1'b0, word_q[26:18]} + sum_q[29:20];
    wire [9:0] sg = {1'b0, word_q[17:9]} + sum_q[19:10];
    wire [9:0] sb = {1'b0, word_q[8:0]} + sum_q[9:0];
    wire [15:0] average     = {sr[9:5], sg[9:4], sb[9:5]};
    assign busy               = state != 0;
    assign app_wr_mask        = 0;
    assign transaction_active = state == 2 || state == 3 || state == 5 || state == 6;
    wire admit                = !SUPPORT_ARBITRATION || !pause_admission;
    wire idle    = controller_init_done && !controller_busy && !refresh_active && gap == 0;
    wire receive = sdram_rd_valid && state >= 1 && state <= 3;
    always @(posedge clk) begin
        sum_q <= sums[receive ? column:state == 5 ? write_col + 1'b1:write_col];
        if (valid_q) begin
            if (!row_q)
                sums[col_q] <=
                    {2'd0, 1'b0, word_q[26:18], 1'b0, word_q[17:9], 1'b0, word_q[8:0]};
            else if (col_q[0])
                sums[col_q >> 1] <= {average, pair};
        end
    end
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            state       <= 0;
            image       <= 0;
            row         <= 0;
            issued      <= 0;
            returned    <= 0;
            burst       <= 0;
            gap         <= 0;
            col         <= 0;
            row_half    <= 0;
            write_col   <= 0;
            done        <= 0;
            error_code  <= 0;
            app_rd_en   <= 0;
            app_rd_addr <= 0;
            app_wr_en   <= 0;
            app_wr_addr <= 0;
            app_wr_data <= 0;
            valid_q     <= 0;
            word_q      <= 0;
            col_q       <= 0;
            row_q       <= 0;
            pair        <= 0;
        end else begin
            done      <= 0;
            app_rd_en <= 0;
            app_wr_en <= 0;
            valid_q   <= receive;
            if (gap != 0)
                gap <= gap - 1'b1;
            if (receive) begin
                word_q   <= {5'd0, hr, hg, hb};
                col_q    <= column;
                row_q    <= row_half;
                returned <= returned + 1'b1;
                if (col == 319) begin
                    col      <= 0;
                    row_half <= ~row_half;
                end else
                    col <= col + 1'b1;
            end
            if (valid_q && row_q && !col_q[0])
                pair <= average;
            case (state)
                0:
                    if (start) begin
                        state      <= 1;
                        image      <= 0;
                        row        <= 0;
                        issued     <= 0;
                        returned   <= 0;
                        col        <= 0;
                        row_half   <= 0;
                        gap        <= 12;
                        error_code <= 0;
                    end
                1:
                    if (idle && admit) begin
                        state <= 2;
                        burst <= 0;
                    end
                2: begin
                    app_rd_en   <= 1;
                    app_rd_addr <= image * 21'd153600 + row * 21'd640 + issued;
                    issued      <= issued + 1'b1;
                    if (burst == 127) begin
                        state <= 3;
                        gap   <= 12;
                    end else
                        burst <= burst + 1'b1;
                end
                3:
                    if (returned == issued && !valid_q && gap == 0) begin
                        if (issued == 640) begin
                            if (!image[0]) begin
                                image    <= image + 1'b1;
                                issued   <= 0;
                                returned <= 0;
                                col      <= 0;
                                row_half <= 0;
                                state    <= 1;
                            end else begin
                                state     <= 4;
                                write_col <= 0;
                            end
                        end else
                            state <= 1;
                    end
                // One RAM prime cycle before a continuous 128-word write burst.
                4:
                    if (idle && admit) begin
                        state <= 5;
                        burst <= 0;
                    end
                5: begin
                    app_wr_en <= 1;
                    app_wr_addr <=
                        21'd614400 + (row + (image[1] ? 21'd240 : 0)) * 21'd320 + write_col;
                    app_wr_data <= sum_q;
                    write_col   <= write_col + 1'b1;
                    if (burst == 127 || write_col == 319) begin
                        state <= 6;
                        gap   <= 12;
                    end else
                        burst <= burst + 1'b1;
                end
                6:
                    if (idle) begin
                        if (write_col == 320) begin
                            if (row == 239 && image == 3) begin
                                state <= 0;
                                done  <= 1;
                            end else begin
                                if (row == 239) begin
                                    image <= 2;
                                    row   <= 0;
                                end else begin
                                    image <= image - 1'b1;
                                    row   <= row + 1'b1;
                                end
                                issued   <= 0;
                                returned <= 0;
                                col      <= 0;
                                row_half <= 0;
                                state    <= 1;
                            end
                        end else
                            state <= 4;
                    end
                default: begin
                    state      <= 0;
                    error_code <= 8'hb1;
                    done       <= 1;
                end
            endcase
        end
endmodule
