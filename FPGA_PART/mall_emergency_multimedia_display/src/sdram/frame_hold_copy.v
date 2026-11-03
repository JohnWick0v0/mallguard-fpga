// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：复制当前完整帧供维护路径保留，按SDRAM事务完成条件提交。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Copy one complete RGB565 surface into video bank 0 in eight-word bursts.
// The 256-bit shift register uses flip-flops, not another block RAM.
module frame_hold_copy #(
    parameter integer WORDS   = 153600,
    parameter [20:0]  DEST = 21'd1382400
)(
    input wire         clk,
                       rst_n,
                       start,
                       admit,
                       controller_busy,
                       refresh,
    input wire [20:0]  source_base,
    input wire         rd_valid,
    input wire [31:0]  rd_data,
    output wire        busy,
                       transaction_active,
    output reg         done,
    output reg         rd_en,
                       wr_en,
    output reg [20:0]  rd_addr,
                       wr_addr,
    output wire [31:0] wr_data
);
    reg [2:0] state;
    reg [17:0] offset;
    reg [3:0] issued, returned;
    reg [4:0] gap;
    reg [20:0] base;
    reg [255:0] words;
    assign busy               = state != 0;
    assign transaction_active = state == 2 || state == 3 || state == 5 || state == 6;
    assign wr_data            = words[31:0];
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            state    <= 0;
            offset   <= 0;
            issued   <= 0;
            returned <= 0;
            gap      <= 0;
            base     <= 0;
            words    <= 0;
            done     <= 0;
            rd_en    <= 0;
            wr_en    <= 0;
            rd_addr  <= 0;
            wr_addr  <= 0;
        end else begin
            done  <= 0;
            rd_en <= 0;
            wr_en <= 0;
            if (gap != 0)
                gap <= gap - 1'b1;
            if (rd_valid && (state == 2 || state == 3)) begin
                words    <= {rd_data, words[255:32]};
                returned <= returned + 1'b1;
            end
            case (state)
                0:
                    if (start) begin
                        base   <= source_base;
                        offset <= 0;
                        gap    <= 12;
                        state  <= 1;
                    end
                1:
                    if (admit && !controller_busy && !refresh && gap == 0) begin
                        issued   <= 0;
                        returned <= 0;
                        state    <= 2;
                    end
                2: begin
                    rd_en   <= 1;
                    rd_addr <= base + offset + issued;
                    issued  <= issued + 1'b1;
                    if (issued == 7) begin
                        state <= 3;
                        gap   <= 12;
                    end
                end
                3:
                    if (returned == 8 && gap == 0 && !controller_busy) begin
                        issued <= 0;
                        state  <= 4;
                    end
                4:
                    if (admit && !controller_busy && !refresh)
                        state <= 5;
                // wr_en and address are registered; shift only AFTER the accepted word.
                5: begin
                    wr_en   <= 1;
                    wr_addr <= DEST + offset + issued;
                    if (wr_en)
                        words <= {32'd0, words[255:32]};
                    issued <= issued + 1'b1;
                    if (issued == 7) begin
                        state <= 6;
                        gap   <= 12;
                    end
                end
                6: begin
                    if (wr_en)
                        words <= {32'd0, words[255:32]};
                    if (gap == 0 && !controller_busy) begin
                        if (offset + 8 == WORDS) begin
                            done  <= 1;
                            state <= 0;
                        end else begin
                            offset <= offset + 8;
                            state  <= 1;
                        end
                    end
                end
                default:
                    state <= 0;
            endcase
        end
endmodule
