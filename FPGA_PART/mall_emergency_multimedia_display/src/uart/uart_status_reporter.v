// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：周期输出S25等兼容状态帧，快照字段并计算XOR校验。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Atomic, periodic ASCII telemetry. Payload bytes0..39 XOR into two hex
// checksum digits. RX control remains the existing eight-command interface.
// @S20,0000,1,A,02710,80,FF,00,0,F,1,80,FF*CS\r\n
module uart_status_reporter #(
    parameter integer CLKS_PER_BIT         = 434,
    parameter integer SUPPORT_EXPERIENCE = 0,
    parameter integer REPORT_CYCLES      = 12500000,
    parameter integer SUPPORT_FINDER     = 0,
    parameter integer SUPPORT_VIDEO      = 0,
    parameter [7:0]   BUILD_TAG_A = 8'h0d,
                      BUILD_TAG_B = 8'h0a
)(
    input wire        clk,
                      rst_n,
                      enable,
    input wire [1:0]  media_id,
    input wire [7:0]  volume,
    input wire [31:0] period_ms,
    input wire        auto_enabled,
    input wire        switch_event,
                      menu_event,
    input wire [1:0]  menu_kind,
    input wire [7:0]  error_code,
    input wire        bright_event,
    input wire [7:0]  bright_value,
    input wire        alarm_active,
    input wire [2:0]  alarm_kind,
    input wire [3:0]  ready_pages,
    input wire [1:0]  notice_kind,
    input wire [15:0] notice_id,
    input wire [3:0]  notice_flags,
                      notice_error,
    input wire [1:0]  selected_slot,
    input wire [7:0]  video_flags,
                      video_frame,
                      video_fault,
    input wire [7:0]  load_flags,
                      load_progress,
                      receipt_sequence,
                      receipt_command,
                      receipt_status,
                      config_flags,
                      manual_counter,
    input wire        boot_ready,
    output wire       uart_tx
);
    localparam integer TIMER_W = REPORT_CYCLES <= 2 ? 1 : $clog2(REPORT_CYCLES);
    reg [TIMER_W - 1:0] timer;
    reg pending, sending, start;
    reg [6:0] index;
    reg [1:0] slot;
    reg [7:0] vflags, vframe, vfault;
    reg [55:0] extension;
    reg [15:0] seq;
    reg [1:0] pic;
    reg mode, boot;
    reg [19:0] period;
    reg [7:0] cfg_vol, cfg_bright, error, checksum;
    reg [2:0] alarm;
    reg [3:0] pages;
    reg [1:0] notice;
    reg [15:0] notice_tag;
    reg [3:0] flags, notice_fault;
    wire [7:0] actual_vol    = alarm == 0 ? cfg_vol : alarm == 2 ? 8'd0 : 8'd255;
    wire [7:0] actual_bright = alarm == 0 ? cfg_bright : 8'd255;
    wire busy, done;
    function [7:0] hex;
        input [3:0] n;
        begin
            hex = n < 10 ? "0" + {4'd0, n} : "A" + {4'd0, n} - 8'd10;
        end
    endfunction
    function [7:0] base_character;
        input [6:0] i;
        reg [3:0] nibble;
        reg is_hex;
        reg [7:0] literal;
        begin
            nibble  = 0;
            is_hex  = 1;
            literal = 0;
            case (i)
                5:
                    nibble = seq[15:12];
                6:
                    nibble = seq[11:8];
                7:
                    nibble = seq[7:4];
                8:
                    nibble = seq[3:0];
                14:
                    nibble = period[19:16];
                15:
                    nibble = period[15:12];
                16:
                    nibble = period[11:8];
                17:
                    nibble = period[7:4];
                18:
                    nibble = period[3:0];
                20:
                    nibble = actual_vol[7:4];
                21:
                    nibble = actual_vol[3:0];
                23:
                    nibble = actual_bright[7:4];
                24:
                    nibble = actual_bright[3:0];
                26:
                    nibble = error[7:4];
                27:
                    nibble = error[3:0];
                31:
                    nibble = pages;
                35:
                    nibble = cfg_vol[7:4];
                36:
                    nibble = cfg_vol[3:0];
                38:
                    nibble = cfg_bright[7:4];
                39:
                    nibble = cfg_bright[3:0];
                41:
                    nibble = checksum[7:4];
                42:
                    nibble = checksum[3:0];
                default: begin
                    is_hex = 0;
                    case (i)
                        0:
                            literal = "@";
                        1:
                            literal = "S";
                        2:
                            literal = "2";
                        3:
                            literal = "0";
                        4, 9, 11, 13, 19, 22, 25, 28, 30, 32, 34, 37:
                            literal = ",";
                        10:
                            literal = "1" + {6'd0, pic};
                        12:
                            literal = mode ? "A" : "E";
                        29:
                            literal = "0" + {5'd0, alarm};
                        33:
                            literal = "0" + {7'd0, boot};
                        40:
                            literal = "*";
                        43:
                            literal = 13;
                        44:
                            literal = 10;
                        default:
                            literal = 0;
                    endcase
                end
            endcase
            base_character = is_hex ? hex(nibble) : literal;
        end
    endfunction
    function [7:0] character;
        input [6:0] i;
        reg [3:0] n;
        reg is_hex;
        reg [7:0] c;
        begin
            n      = 0;
            is_hex = 0;
            c      = base_character(i);
            if (SUPPORT_FINDER) begin
                if (i == 3)
                    c = "1";
                else if (i >= 40)
                    case (i)
                        40, 42, 47, 49:
                            c = ",";
                        41: begin
                            n      = {2'd0, notice};
                            is_hex = 1;
                        end
                        43: begin
                            n      = notice_tag[15:12];
                            is_hex = 1;
                        end
                        44: begin
                            n      = notice_tag[11:8];
                            is_hex = 1;
                        end
                        45: begin
                            n      = notice_tag[7:4];
                            is_hex = 1;
                        end
                        46: begin
                            n      = notice_tag[3:0];
                            is_hex = 1;
                        end
                        48: begin
                            n      = flags;
                            is_hex = 1;
                        end
                        50: begin
                            n      = notice_fault;
                            is_hex = 1;
                        end
                        51:
                            c = "*";
                        52: begin
                            n      = checksum[7:4];
                            is_hex = 1;
                        end
                        53: begin
                            n      = checksum[3:0];
                            is_hex = 1;
                        end
                        54:
                            c = 13;
                        55:
                            c = 10;
                        default:
                            c = 0;
                    endcase
            end
            if (SUPPORT_VIDEO) begin
                if (i == 3)
                    c = "3";
                if (i >= 51)
                    case (i)
                        51, 53, 56, 59: begin
                            c      = ",";
                            is_hex = 0;
                        end
                        52: begin
                            n      = {2'd0, slot};
                            is_hex = 1;
                        end
                        54: begin
                            n      = vflags[7:4];
                            is_hex = 1;
                        end
                        55: begin
                            n      = vflags[3:0];
                            is_hex = 1;
                        end
                        57: begin
                            n      = vframe[7:4];
                            is_hex = 1;
                        end
                        58: begin
                            n      = vframe[3:0];
                            is_hex = 1;
                        end
                        60: begin
                            n      = vfault[7:4];
                            is_hex = 1;
                        end
                        61: begin
                            n      = vfault[3:0];
                            is_hex = 1;
                        end
                        62: begin
                            c      = "*";
                            is_hex = 0;
                        end
                        63: begin
                            n      = checksum[7:4];
                            is_hex = 1;
                        end
                        64: begin
                            n      = checksum[3:0];
                            is_hex = 1;
                        end
                        65: begin
                            c      = 13;
                            is_hex = 0;
                        end
                        66: begin
                            c      = 10;
                            is_hex = 0;
                        end
                        default: begin
                            c      = 0;
                            is_hex = 0;
                        end
                    endcase
            end
            if (SUPPORT_EXPERIENCE) begin
                if (i == 3)
                    c = "5";
                if (i >= 62)
                    case (i)
                        62: begin
                            c      = ",";
                            is_hex = 0;
                        end
                        63: begin
                            n      = extension[55:52];
                            is_hex = 1;
                        end
                        64: begin
                            n      = extension[51:48];
                            is_hex = 1;
                        end
                        65: begin
                            c      = ",";
                            is_hex = 0;
                        end
                        66: begin
                            n      = extension[47:44];
                            is_hex = 1;
                        end
                        67: begin
                            n      = extension[43:40];
                            is_hex = 1;
                        end
                        68: begin
                            c      = ",";
                            is_hex = 0;
                        end
                        69: begin
                            n      = extension[39:36];
                            is_hex = 1;
                        end
                        70: begin
                            n      = extension[35:32];
                            is_hex = 1;
                        end
                        71: begin
                            c      = ",";
                            is_hex = 0;
                        end
                        72: begin
                            n      = extension[31:28];
                            is_hex = 1;
                        end
                        73: begin
                            n      = extension[27:24];
                            is_hex = 1;
                        end
                        74: begin
                            c      = ",";
                            is_hex = 0;
                        end
                        75: begin
                            n      = extension[23:20];
                            is_hex = 1;
                        end
                        76: begin
                            n      = extension[19:16];
                            is_hex = 1;
                        end
                        77: begin
                            c      = ",";
                            is_hex = 0;
                        end
                        78: begin
                            n      = extension[15:12];
                            is_hex = 1;
                        end
                        79: begin
                            n      = extension[11:8];
                            is_hex = 1;
                        end
                        80: begin
                            c      = ",";
                            is_hex = 0;
                        end
                        81: begin
                            n      = extension[7:4];
                            is_hex = 1;
                        end
                        82: begin
                            n      = extension[3:0];
                            is_hex = 1;
                        end
                        83: begin
                            c      = "*";
                            is_hex = 0;
                        end
                        84: begin
                            n      = checksum[7:4];
                            is_hex = 1;
                        end
                        85: begin
                            n      = checksum[3:0];
                            is_hex = 1;
                        end
                        86: begin
                            c      = 13;
                            is_hex = 0;
                        end
                        87: begin
                            c      = 10;
                            is_hex = 0;
                        end
                        default: begin
                            c      = 0;
                            is_hex = 0;
                        end
                    endcase
            end
            character = is_hex ? hex(n) : c;
        end
    endfunction
    uart_tx_byte #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data(character(index)),
        .tx(uart_tx),
        .busy(busy),
        .done(done)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            extension    <= 0;
            slot         <= 0;
            vflags       <= 0;
            vframe       <= 0;
            vfault       <= 0;
            timer        <= 0;
            pending      <= 1;
            sending      <= 0;
            start        <= 0;
            index        <= 0;
            seq          <= 16'hffff;
            notice       <= 0;
            notice_tag   <= 0;
            flags        <= 0;
            notice_fault <= 0;
            pic          <= 0;
            mode         <= 0;
            boot         <= 0;
            period       <= 0;
            cfg_vol      <= 0;
            cfg_bright   <= 0;
            error        <= 0;
            checksum     <= 0;
            alarm        <= 0;
            pages        <= 0;
        end else begin
            start <= 0;
            if (timer == REPORT_CYCLES - 1) begin
                timer   <= 0;
                pending <= 1;
            end else
                timer <= timer + 1'b1;
            if (!sending) begin
                if (enable && pending) begin
                    pending      <= 0;
                    sending      <= 1;
                    index        <= 0;
                    checksum     <= 0;
                    seq          <= seq + 1'b1;
                    extension    <= {load_flags,
                        load_progress,
                        receipt_sequence,
                        receipt_command,
                        receipt_status,
                        config_flags,
                        manual_counter};
                    slot         <= selected_slot;
                    vflags       <= video_flags;
                    vframe       <= video_frame;
                    vfault       <= video_fault;
                    notice       <= notice_kind;
                    notice_tag   <= notice_id;
                    flags        <= notice_flags;
                    notice_fault <= notice_error;
                    pic          <= media_id;
                    mode         <= auto_enabled;
                    boot         <= boot_ready;
                    period       <= period_ms[19:0];
                    cfg_vol      <= volume;
                    cfg_bright   <= bright_value;
                    error        <= error_code;
                    alarm        <= alarm_active ? alarm_kind : 3'd0;
                    pages        <= ready_pages;
                end
            end else if (done) begin
                if (index == (SUPPORT_EXPERIENCE  ? 87
                                 : SUPPORT_VIDEO  ? 66
                                 : SUPPORT_FINDER ? 55
                                                  : 44)) begin
                    sending <= 0;
                    index   <= 0;
                end else
                    index <= index + 1'b1;
            end else if (!busy && !start) begin
                start <= 1;
                if (index < (SUPPORT_EXPERIENCE  ? 83
                                : SUPPORT_VIDEO  ? 62
                                : SUPPORT_FINDER ? 51
                                                 : 40))
                    checksum <= checksum ^ character(index);
            end
        end
    end
endmodule
