// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：解析fire/put_out等四类应急命令，输出事件类型和进入/结束脉冲。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Board UART RX: idle-high 115200 8N1, center sampled. Whole ASCII tokens
// fire / put_out terminate on CR/LF or 2 ms idle; malformed frames are dropped.
module emergency_uart_control #(
    parameter integer CLKS_PER_BIT  = 434,
    parameter integer IDLE_CYCLES = 100000
)(
    input wire        clk,
                      rst_n,
                      uart_rx,
    output reg        fire_event,
                      put_out_event,
    output reg        start_valid,
                      end_valid,
    output reg [2:0]  start_kind,
                      end_kind,
    output wire       rx_byte_valid,
    output wire [7:0] rx_byte,
    output reg        framing_error
);
    (* async_reg = "true" *) reg rx_s1, rx_s2;
    reg [2:0] state;
    reg [15:0] bit_timer;
    reg [2:0] bit_index;
    reg [7:0] shift;
    reg byte_valid;
    reg [7:0] received;
    assign rx_byte_valid = byte_valid;
    assign rx_byte       = received;
    reg [3:0] length;
    reg overflow;
    reg [7:0] candidates;
    // Verilog-2001兼容：循环索引在模块级声明，综合时仍展开为8路匹配。
    integer c;
    reg [$clog2(IDLE_CYCLES + 1) - 1:0] idle_timer;
    wire [7:0] lower = (received >= 8'h41 && received <= 8'h5a) ? received + 8'h20 : received;
    function [7:0] expected_char;
        input [2:0] command_id;
        input [3:0] position;
        begin
            case (command_id)
                0:
                    expected_char = ("fire" >> ((3 - position) * 8)) & 255;
                1:
                    expected_char = ("put_out" >> ((6 - position) * 8)) & 255;
                2:
                    expected_char = ("power_outage" >> ((11 - position) * 8)) & 255;
                3:
                    expected_char = ("power_back" >> ((9 - position) * 8)) & 255;
                4:
                    expected_char = ("incident" >> ((7 - position) * 8)) & 255;
                5:
                    expected_char = ("security" >> ((7 - position) * 8)) & 255;
                6:
                    expected_char = ("doctor" >> ((5 - position) * 8)) & 255;
                7:
                    expected_char = ("safe" >> ((3 - position) * 8)) & 255;
            endcase
        end
    endfunction
    task finish_token;
        begin
            if (!overflow) begin
                if (candidates[0] && length == 4) begin
                    fire_event  <= 1;
                    start_valid <= 1;
                    start_kind  <= 1;
                end
                if (candidates[1] && length == 7) begin
                    put_out_event <= 1;
                    end_valid     <= 1;
                    end_kind      <= 1;
                end
                if (candidates[2] && length == 12) begin
                    start_valid <= 1;
                    start_kind  <= 2;
                end
                if (candidates[3] && length == 10) begin
                    end_valid <= 1;
                    end_kind  <= 2;
                end
                if (candidates[4] && length == 8) begin
                    start_valid <= 1;
                    start_kind  <= 3;
                end
                if (candidates[5] && length == 8) begin
                    end_valid <= 1;
                    end_kind  <= 3;
                end
                if (candidates[6] && length == 6) begin
                    start_valid <= 1;
                    start_kind  <= 4;
                end
                if (candidates[7] && length == 4) begin
                    end_valid <= 1;
                    end_kind  <= 4;
                end
            end
            candidates <= 8'hff;
            length     <= 0;
            overflow   <= 0;
            idle_timer <= 0;
        end
    endtask
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_s1 <= 1;
            rx_s2 <= 1;
        end else begin
            rx_s1 <= uart_rx;
            rx_s2 <= rx_s1;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= 0;
            bit_timer     <= 0;
            bit_index     <= 0;
            shift         <= 0;
            byte_valid    <= 0;
            received      <= 0;
            framing_error <= 0;
        end else begin
            byte_valid    <= 0;
            framing_error <= 0;
            case (state)
                0:
                    if (!rx_s2) begin
                        bit_timer <= CLKS_PER_BIT / 2 - 1;
                        state     <= 1;
                    end
                1:
                    if (bit_timer != 0)
                        bit_timer <= bit_timer - 1'b1;
                    else if (rx_s2)
                        state <= 0;
                    else begin
                        bit_timer <= CLKS_PER_BIT - 1;
                        bit_index <= 0;
                        state     <= 2;
                    end
                2:
                    if (bit_timer != 0)
                        bit_timer <= bit_timer - 1'b1;
                    else begin
                        shift[bit_index] <= rx_s2;
                        bit_timer        <= CLKS_PER_BIT - 1;
                        if (bit_index == 7)
                            state <= 3;
                        else
                            bit_index <= bit_index + 1'b1;
                    end
                3:
                    if (bit_timer != 0)
                        bit_timer <= bit_timer - 1'b1;
                    else if (rx_s2) begin
                        received   <= shift;
                        byte_valid <= 1;
                        state      <= 0;
                    end else begin
                        framing_error <= 1;
                        state         <= 4;
                    end
                4:
                    if (rx_s2)
                        state <= 0;
                default:
                    state <= 0;
            endcase
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            candidates    <= 255;
            length        <= 0;
            overflow      <= 0;
            idle_timer    <= 0;
            fire_event    <= 0;
            put_out_event <= 0;
            start_valid   <= 0;
            end_valid     <= 0;
            start_kind    <= 0;
            end_kind      <= 0;
        end else begin
            fire_event    <= 0;
            put_out_event <= 0;
            start_valid   <= 0;
            end_valid     <= 0;
            if (framing_error) begin
                candidates <= 255;
                length     <= 0;
                overflow   <= 1;
                idle_timer <= 0;
            end else if (byte_valid) begin
                idle_timer <= 0;
                if (received == 13 || received == 10)
                    finish_token();
                else if (length < 12) begin
                    for (c = 0; c < 8; c = c + 1)
                        candidates[c] <= candidates[c] && lower == expected_char(c, length);
                    length <= length + 1'b1;
                end else
                    overflow <= 1;
            end else if ((length != 0 || overflow) && state == 0 && rx_s2) begin
                if (idle_timer == IDLE_CYCLES - 1)
                    finish_token();
                else
                    idle_timer <= idle_timer + 1'b1;
            end else
                idle_timer <= 0;
        end
    end
endmodule
