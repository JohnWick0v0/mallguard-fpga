// 回归用途：flash_capture_window；从已归档的最终验证台迁移。
// 断言覆盖的功能保持原样；仿真工作/日志放在sim/work和sim/results。
`timescale 1ns / 1ps
// Real journal controller and CRC logic; Flash transaction model supplies records.
// A deliberately wrong first CRC capture models a result taking >1 clock but <2.
module tb_flash_crc_windows;
    reg clk = 0, rst_n = 0, load_start = 0, save_start = 0;
    always
        #10 clk = ~clk;
    reg [31:0] save_period = 500000000;
    reg [7:0] save_volume = 128, save_mode = 1;
    wire load_done, save_done, valid, busy;
    wire [31:0] version, period;
    wire [7:0] volume, mode;
    integer delayed_captures = 0, delayed_captures0 = 0, checks = 0;
    time slot1_changed = 0, slot0_changed = 0;
    config_flash_journal dut (
        .clk(clk),
        .rst_n(rst_n),
        .load_start(load_start),
        .save_start(save_start),
        .save_period(save_period),
        .save_volume(save_volume),
        .save_mode(save_mode),
        .busy(busy),
        .load_done(load_done),
        .save_done(save_done),
        .config_valid(valid),
        .active_version(version),
        .active_period(period),
        .active_volume(volume),
        .active_mode(mode),
        .spi_miso(1'b1)
    );
    function automatic[15:0] crc
        (input [79:0] p);
        reg [15:0] c;
        integer n;
        begin
            c = 16'hffff;
            for (n = 79; n >= 0; n = n - 1)
                c = (c << 1) ^ ((c[15] ^ p[n]) ? 16'h1021 : 16'h0000);
            crc = c;
        end
    endfunction
    function automatic[95:0] record
        (input [31:0] v,
            input [31:0] p,
            input [7:0] vol,
            input [7:0] m);
        record = {v, p, vol, m, crc({v, p, vol, m})};
    endfunction
    // Deliberately corrupt the first slot0 CRC capture for a complete clock.
    // The actual controller must finish the slot1 transaction before using it.
    always @(dut.slot0_data)
        if (rst_n) begin
            slot0_changed = $time;
            delayed_captures0 = delayed_captures0 + 1;
            if (dut.slot0_data[15:0] == crc(dut.slot0_data[95:16]) &&
                dut.slot0_data != {96{1'b1}})
                force dut.u_journal.slot0_good = 1'b0;
            else
                force dut.u_journal.slot0_good = 1'b1;
            #30;
            release dut.u_journal.slot0_good;
        end
    always @(dut.slot1_data)
        if (rst_n) begin
            slot1_changed    = $time;
            delayed_captures = delayed_captures + 1;
            if (dut.slot1_data[15:0] == crc(dut.slot1_data[95:16]) &&
                dut.slot1_data != {96{1'b1}})
                force dut.u_journal.slot1_good = 1'b0;
            else
                force dut.u_journal.slot1_good = 1'b1;
            #30;
            release dut.u_journal.slot1_good;
        end
    always @(posedge clk)
        if (rst_n && (dut.u_journal.load_pending || dut.journal_save_start)) begin
            if ($time - slot0_changed < 40)
                $fatal(1, "Slot0 CRC consumed before two-clock data window");
            if ($time - slot1_changed < 40)
                $fatal(1, "CRC consumed before two-clock data window");
        end
    task automatic load
        (input [95:0] a,
            input [95:0] b,
            input bit good,
            input [31:0] v,
            input [31:0] p);
        begin
            @(negedge clk);
            dut.u_store.record0 = a;
            dut.u_store.record1 = b;
            load_start          = 1;
            @(negedge clk);
            load_start = 0;
            wait(load_done);
            #1;
            if (valid !== good || version !== v || period !== p)
                $fatal(1,
                    "Load mismatch got %b %h %h expected %b %h %h",
                    valid,
                    version,
                    period,
                    good,
                    v,
                    p);
            checks = checks + 1;
            @(negedge clk);
        end
    endtask
    task automatic save
        (input [31:0] p,
            input [7:0] vol,
            input [7:0] m,
            input [31:0] expected_version);
        begin
            @(negedge clk);
            save_period = p;
            save_volume = vol;
            save_mode   = m;
            save_start  = 1;
            @(negedge clk);
            save_start = 0;
            wait(save_done);
            #1;
            if (!valid || version !== expected_version || period !== p || volume !== vol ||
                mode !== m)
                $fatal(1, "Save/reload mismatch");
            checks = checks + 1;
            @(negedge clk);
        end
    endtask
    reg [95:0] a, b;
    integer n;
    initial begin
        repeat (4) @(negedge clk)
            ;
        rst_n = 1;
        load({96{1'b1}}, {96{1'b1}}, 0, 0, 0);
        a = record(3, 100, 64, 0);
        b = record(4, 200, 192, 1);
        load(a, b, 1, 4, 200);
        load(a, b ^ 96'h1, 1, 3, 100);
        load(a ^ 96'h1, b, 1, 4, 200);
        load(a ^ 96'h1, b ^ 96'h1, 0, 0, 0);
        load(record(32'hffffffff, 300, 255, 1), record(0, 400, 128, 0), 1, 0, 400);
        save(123456789, 64, 1, 1);
        save(987654321, 255, 0, 2);
        for (n = 0; n < 16; n = n + 1) begin
            a = record(n * 2, 500 + n, 64, 0);
            b = record(n * 2 + 1, 900 + n, 192, 1);
            load(a, b, 1, n * 2 + 1, 900 + n);
            load(a, b ^ 96'h1000000000000000, 1, n * 2, 500 + n);
        end
        if (delayed_captures0 < 15 || delayed_captures < 30)
            $fatal(1, "Insufficient delayed captures");
        $display(
            "TEST PASSED flash_crc_windows: %0d loads/save-reloads, slot0=%0d and slot1=%0d wrong first captures; both earliest uses >= two clocks",
            checks,
            delayed_captures0,
            delayed_captures);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Journal timeout");
    end
endmodule

// Transaction-level model; this test does not claim Flash SPI pin coverage.
module w25q64_record_store #(
    parameter        CLK_DIV = 2,
                     CS_HIGH_CYCLES = 3,
                     POLL_INTERVAL_CYCLES = 5000,
    parameter [31:0] ERASE_TIMEOUT_CYCLES = 250000000,
                     PROGRAM_TIMEOUT_CYCLES = 5000000,
    parameter [23:0] ALLOWED_BASE = 24'h1000,
                     ALLOWED_LIMIT = 24'h3000
)(
    input             clk,
                      rst_n,
                      start,
                      op_write,
    input [23:0]      address,
    input [95:0]      write_data,
    output reg        busy,
                      done,
                      error,
    output reg [3:0]  error_code,
    output reg [95:0] read_data,
    output reg        request_dropped,
    output            spi_cs_n,
                      spi_sclk,
                      spi_mosi,
    input             spi_miso,
    output            spi_wp_n,
                      spi_hold_n
);
    reg [95:0] record0 = {96{1'b1}}, record1 = {96{1'b1}};
    reg [2:0] remaining;
    assign spi_cs_n   = 1;
    assign spi_sclk   = 0;
    assign spi_mosi   = 0;
    assign spi_wp_n   = 1;
    assign spi_hold_n = 1;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            busy            <= 0;
            done            <= 0;
            error           <= 0;
            error_code      <= 0;
            read_data       <= 0;
            request_dropped <= 0;
            remaining       <= 0;
        end else begin
            done <= 0;
            if (start && !busy) begin
                busy      <= 1;
                remaining <= 3;
                if (op_write) begin
                    if (address == 24'h1000)
                        record0 <= write_data;
                    else
                        record1 <= write_data;
                end else
                    read_data <= (address == 24'h1000) ? record0 : record1;
            end else if (busy) begin
                if (remaining == 1) begin
                    busy      <= 0;
                    done      <= 1;
                    remaining <= 0;
                end else
                    remaining <= remaining - 1;
            end
        end
endmodule
