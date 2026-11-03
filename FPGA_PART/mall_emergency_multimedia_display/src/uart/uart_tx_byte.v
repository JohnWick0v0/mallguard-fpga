// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：按配置波特率发送一个UART字节，提供忙/完成握手。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// Byte-oriented 8N1 transmitter inherited from the verified HX4S20C UART path.
module uart_tx_byte #(
    parameter integer CLKS_PER_BIT = 434
)(
    input wire       clk,
    input wire       rst_n,
    input wire       start,
    input wire [7:0] data,
    output reg       tx,
    output reg       busy,
    output reg       done
);
    reg [31:0] clk_count;
    reg [3:0] bit_index;
    reg [9:0] frame;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_count <= 32'd0;
            bit_index <= 4'd0;
            frame     <= 10'h3ff;
            tx        <= 1'b1;
            busy      <= 1'b0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                tx        <= 1'b1;
                clk_count <= 32'd0;
                bit_index <= 4'd0;
                if (start) begin
                    frame <= {1'b1, data, 1'b0};
                    tx    <= 1'b0;
                    busy  <= 1'b1;
                end
            end else if (clk_count == CLKS_PER_BIT - 1) begin
                clk_count <= 32'd0;
                if (bit_index == 4'd9) begin
                    tx        <= 1'b1;
                    busy      <= 1'b0;
                    done      <= 1'b1;
                    bit_index <= 4'd0;
                end else begin
                    bit_index <= bit_index + 1'b1;
                    tx        <= frame[bit_index + 1'b1];
                end
            end else begin
                clk_count <= clk_count + 1'b1;
            end
        end
    end
endmodule
