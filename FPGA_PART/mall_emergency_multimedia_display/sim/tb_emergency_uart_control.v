`timescale 1ns / 1ps
// 串口兼容性回归：真实8N1字节流、四类应急、匹配解除、非法命令及空闲结束符。
module tb_emergency_uart_control;
    localparam integer BIT_CYCLES = 8;
    localparam integer IDLE_CYCLES = 100;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg uart_rx = 1;
    wire fire_event, put_out_event, start_valid, end_valid;
    wire [2:0] start_kind, end_kind, active_kind;
    wire byte_valid, framing_error, requested;
    wire [7:0] byte_data;
    integer start_count = 0;
    integer end_count = 0;
    integer before_count;

    emergency_uart_control #(
        .CLKS_PER_BIT(BIT_CYCLES),
        .IDLE_CYCLES(IDLE_CYCLES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .fire_event(fire_event),
        .put_out_event(put_out_event),
        .start_valid(start_valid),
        .end_valid(end_valid),
        .start_kind(start_kind),
        .end_kind(end_kind),
        .rx_byte_valid(byte_valid),
        .rx_byte(byte_data),
        .framing_error(framing_error)
    );

    emergency_session_controller session (
        .clk(clk),
        .rst_n(rst_n),
        .start_valid(start_valid),
        .end_valid(end_valid),
        .start_kind(start_kind),
        .end_kind(end_kind),
        .frame_active_sys(1'b0),
        .requested(requested),
        .kind(active_kind)
    );

    always @(posedge clk) begin
        if (rst_n && start_valid) start_count = start_count + 1;
        if (rst_n && end_valid) end_count = end_count + 1;
    end

    task send_byte;
        input [7:0] value;
        integer bit_number;
        begin
            @(negedge clk);
            uart_rx = 0;
            repeat (BIT_CYCLES) @(negedge clk);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                uart_rx = value[bit_number];
                repeat (BIT_CYCLES) @(negedge clk);
            end
            uart_rx = 1;
            repeat (BIT_CYCLES) @(negedge clk);
        end
    endtask

    task send_text;
        input [127:0] value;
        input integer length;
        integer character;
        begin
            for (character = length - 1; character >= 0; character = character - 1)
                send_byte(value >> (character * 8));
        end
    endtask

    task send_line;
        input [127:0] value;
        input integer length;
        begin
            send_text(value, length);
            send_byte(8'd13);
            send_byte(8'd10);
            repeat (20) @(negedge clk);
        end
    endtask

    task expect_session;
        input active;
        input [2:0] kind;
        begin
            if (requested !== active || (active && active_kind !== kind)) begin
                $display("TEST FAILED: session expected active=%b kind=%d, got %b/%d", active, kind, requested, active_kind);
                $finish;
            end
        end
    endtask

    initial begin
        repeat (6) @(negedge clk);
        rst_n = 1;
        send_line("fire", 4);
        expect_session(1, 1);
        if (start_count != 1) begin
            $display("TEST FAILED: CRLF dispatched the fire command more than once");
            $finish;
        end
        send_line("doctor", 6);
        expect_session(1, 1);
        send_line("safe", 4);
        expect_session(1, 1);
        send_line("put_out", 7);
        expect_session(0, 0);
        send_line("power_outage", 12);
        expect_session(1, 2);
        send_line("power_back", 10);
        expect_session(0, 0);
        send_line("incident", 8);
        expect_session(1, 3);
        send_line("security", 8);
        expect_session(0, 0);
        send_line("doctor", 6);
        expect_session(1, 4);
        send_line("safe", 4);
        expect_session(0, 0);
        before_count = start_count;
        send_line("fireman", 7);
        expect_session(0, 0);
        if (start_count != before_count) begin
            $display("TEST FAILED: invalid command accepted");
            $finish;
        end
        send_text("FIRE", 4);
        repeat (IDLE_CYCLES + 30) @(negedge clk);
        expect_session(1, 1);
        send_line("put_out", 7);
        expect_session(0, 0);
        $display("TEST PASSED: Verilog-2001 UART, all eight commands, CRLF, idle delimiter, case folding and emergency mutual exclusion");
        $finish;
    end

    initial begin
        #500000;
        $display("TEST FAILED: UART regression timeout");
        $finish;
    end
endmodule
