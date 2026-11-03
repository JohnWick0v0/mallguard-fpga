// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：SPI模式SD卡字节收发；处理位时钟与MISO采样。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

module sd_spi_byte_engine #(
    parameter integer CLK_DIV = 4
)(
    input wire       clk,
    input wire       rst_n,
    input wire       start,
    input wire [7:0] tx_byte,
    input wire       miso,
    output reg       busy,
    output reg       done,
    output reg [7:0] rx_byte,
    output reg       sclk,
    output reg       mosi
);

    localparam ST_IDLE          = 2'd0;
    localparam ST_RUN           = 2'd1;
    localparam ST_END           = 2'd2;
    localparam integer DIV_BITS = (CLK_DIV <= 2) ? 1 : $clog2(CLK_DIV);

    reg [1:0] state;
    reg [DIV_BITS - 1:0] div_count;
    reg [2:0] bit_count;
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg sample_pending, last_sample;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            div_count      <= {DIV_BITS{1'b0}};
            bit_count      <= 3'd0;
            tx_shift       <= 8'hff;
            rx_shift       <= 8'h00;
            rx_byte        <= 8'h00;
            busy           <= 1'b0;
            done           <= 1'b0;
            sclk           <= 1'b0;
            mosi           <= 1'b1;
            sample_pending <= 1'b0;
            last_sample    <= 1'b0;
        end else begin
            done           <= 1'b0;
            sample_pending <= 1'b0;
            // Board SCLK travels through an output pad before the card sees
            // it. Capture one mem cycle after the internal rising edge, while
            // external SCLK is still high. DIV=1 then has two mem cycles from
            // the previous falling launch to this sample, rather than one.
            if (sample_pending) begin
                rx_shift <= {rx_shift[6:0], miso};
                if (last_sample)
                    rx_byte <= {rx_shift[6:0], miso};
            end
            case (state)
                ST_IDLE: begin
                    busy      <= 1'b0;
                    sclk      <= 1'b0;
                    div_count <= {DIV_BITS{1'b0}};
                    bit_count <= 3'd0;
                    if (start) begin
                        busy     <= 1'b1;
                        tx_shift <= tx_byte;
                        rx_shift <= 8'h00;
                        mosi     <= tx_byte[7];
                        state    <= ST_RUN;
                    end
                end
                ST_RUN: begin
                    busy <= 1'b1;
                    if (div_count == CLK_DIV - 1) begin
                        div_count <= {DIV_BITS{1'b0}};
                        if (!sclk) begin
                            sclk           <= 1'b1;
                            sample_pending <= 1'b1;
                            last_sample    <= bit_count == 3'd7;
                        end else begin
                            sclk <= 1'b0;
                            if (bit_count == 3'd7) begin
                                state <= ST_END;
                            end else begin
                                bit_count <= bit_count + 1'b1;
                                tx_shift  <= {tx_shift[6:0], 1'b0};
                                // At DIV=1 there is no intermediate low-clock
                                // cycle. Change MOSI on the falling edge so
                                // the card gets a full half-cycle of setup.
                                mosi <= tx_shift[6];
                            end
                        end
                    end else begin
                        div_count <= div_count + 1'b1;
                    end
                end
                ST_END: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    sclk  <= 1'b0;
                    mosi  <= 1'b1;
                    state <= ST_IDLE;
                end
                default:
                    state <= ST_IDLE;
            endcase
        end
    end
endmodule
