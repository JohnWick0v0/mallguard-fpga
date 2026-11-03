// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：接收400×304字模及CRC16，绑定UTF-8名称后发布寻人/寻物，found关闭。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Bounded ASCII control + UTF-8 name binding. The host sends a 400x304 1bpp
// text mask first, then the exact find people/object "name" command.
// CRC16-CCITT-FALSE binds the mask and UTF-8 name. No partial upload is shown.
// 产品说明：400×304一位字模先上传，CRC16及名称绑定通过后发布；仅find文字行不能生成任意中文。
// 设计约定：
// 通知约定：按行接收中文点阵，校验完整性与CRC后发布；未完成通知不覆盖正在显示的卡片。
// 姓名/物品名与字模事务绑定，应急优先时由上层隐藏通知并切换音频。

module finder_notice_controller #(
    parameter integer LINE_TIMEOUT = 5000000
)(
    input wire        clk,
                      rst_n,
                      byte_valid,
    input wire [7:0]  byte_data,
    input wire        emergency_busy,
                      display_visible,
    output reg [1:0]  requested_kind,
    output reg [15:0] notice_id,
    output reg        uploading,
                      mask_ready,
    output reg [3:0]  error,
    output reg        mask_write,
    output reg [13:0] mask_address,
    output reg [7:0]  mask_data
);
    reg [2:0] command;
    reg [7:0] position;
    reg valid, closed;
    reg [15:0] field_id, field_crc, field_name, expected_crc, expected_name, crc;
    reg [1:0] expected_kind, parsed_kind;
    reg [8:0] row_expected;
    reg [15:0] row_field;
    reg [13:0] write_pointer;
    reg [3:0] high_nibble;
    reg [6:0] name_bytes;
    reg [$clog2(LINE_TIMEOUT + 1) - 1:0] idle_count;
    wire [7:0] lower  = byte_data >= "A" && byte_data <= "Z" ? byte_data + 8'd32 : byte_data;
    wire is_hex         = (lower >= "0" && lower <= "9") || (lower >= "a" && lower <= "f");
    wire [3:0] nibble = lower <= "9" ? lower - 8'd48 : lower - 8'd87;
    function [15:0] crc16;
        input[15:0] before;
        input [7:0] value;
        reg [15:0] c;
        integer i;
        begin
            c = before ^ {value, 8'd0};
            for (i = 0; i < 8; i = i + 1)
                c = c[15] ? (c << 1) ^ 16'h1021 : c << 1;
            crc16 = c;
        end
    endfunction
    function [7:0] literal;
        input [2:0] cmd;
        input [7:0] p;
        input [1:0] kind;
        begin
            literal = 0;
            case (cmd)
                1:
                    if (p < 7)
                        literal = ("notice " >> ((6 - p) * 8)) & 255;
                2:
                    if (p < 4)
                        literal = ("row " >> ((3 - p) * 8)) & 255;
                3:
                    if (p < 12)
                        literal = kind == 2 ? ("find object " >> ((11 - p) * 8)) & 255
                                            : ("find people " >> ((11 - p) * 8)) & 255;
                4:
                    if (p < 5)
                        literal = ("found" >> ((4 - p) * 8)) & 255;
            endcase
        end
    endfunction
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            requested_kind <= 0;
            notice_id      <= 0;
            uploading      <= 0;
            mask_ready     <= 0;
            error          <= 0;
            mask_write     <= 0;
            mask_address   <= 0;
            mask_data      <= 0;
            command        <= 0;
            position       <= 0;
            valid          <= 1;
            closed         <= 0;
            field_id       <= 0;
            field_crc      <= 0;
            field_name     <= 0;
            expected_crc   <= 0;
            expected_name  <= 0;
            expected_kind  <= 0;
            parsed_kind    <= 0;
            row_expected   <= 0;
            row_field      <= 0;
            write_pointer  <= 0;
            high_nibble    <= 0;
            name_bytes     <= 0;
            crc            <= 16'hffff;
            idle_count     <= 0;
        end else begin
            mask_write <= 0;
            if (position != 0 && !byte_valid) begin
                if (idle_count == LINE_TIMEOUT - 1) begin
                    position   <= 0;
                    command    <= 0;
                    valid      <= 1;
                    closed     <= 0;
                    idle_count <= 0;
                    if (uploading) begin
                        uploading  <= 0;
                        mask_ready <= 0;
                        error      <= 6;
                    end
                end else
                    idle_count <= idle_count + 1'b1;
            end
            if (byte_valid) begin
                idle_count <= 0;
                if (byte_data == 13 || byte_data == 10) begin
                    if (position != 0)
                        case (command)
                            1:
                                if (valid && position == 23 &&
                                    (parsed_kind == 1 || parsed_kind == 2)) begin
                                    if (emergency_busy)
                                        error <= 5;
                                    else begin
                                        requested_kind <= 0;
                                        notice_id      <= field_id;
                                        expected_crc   <= field_crc;
                                        expected_name  <= field_name;
                                        expected_kind  <= parsed_kind;
                                        uploading      <= 1;
                                        mask_ready     <= 0;
                                        row_expected   <= 0;
                                        write_pointer  <= 0;
                                        crc            <= 16'hffff;
                                        error          <= 0;
                                    end
                                end else
                                    error <= 1;
                            2:
                                if (uploading) begin
                                    if (valid && position == 109 &&
                                        row_field == {7'd0, row_expected}) begin
                                        if (row_expected == 303) begin
                                            uploading <= 0;
                                            if (crc == expected_crc) begin
                                                mask_ready <= 1;
                                                error      <= 0;
                                            end else begin
                                                mask_ready <= 0;
                                                error      <= 3;
                                            end
                                        end else
                                            row_expected <= row_expected + 1'b1;
                                    end else begin
                                        uploading  <= 0;
                                        mask_ready <= 0;
                                        error      <= 2;
                                    end
                                end
                            3:
                                if (emergency_busy)
                                    error <= 5;
                                else if (valid && closed && name_bytes != 0 && mask_ready &&
                                         !uploading && parsed_kind == expected_kind &&
                                         crc == expected_name) begin
                                    requested_kind <= parsed_kind;
                                    error          <= 0;
                                end else
                                    error <= 4;
                            4:
                                if (valid && position == 5) begin
                                    requested_kind <= 0;
                                    uploading      <= 0;
                                    error          <= 0;
                                end
                            default:
                                ;
                        endcase
                    position   <= 0;
                    command    <= 0;
                    valid      <= 1;
                    closed     <= 0;
                    name_bytes <= 0;
                end else if (position == 0) begin
                    position    <= 1;
                    valid       <= 1;
                    closed      <= 0;
                    name_bytes  <= 0;
                    parsed_kind <= 1;
                    command     <= lower == "n" ? 1 : lower == "r" ? 2 : lower == "f" ? 3 : 0;
                    field_id    <= 0;
                    field_crc   <= 0;
                    field_name  <= 0;
                    row_field   <= 0;
                end else begin
                    if (position < 255)
                        position <= position + 1'b1;
                    else
                        valid <= 0;
                    case (command)
                        1: begin
                            if (position < 7) begin
                                if (lower != literal(1, position, 0))
                                    valid <= 0;
                            end else if (position >= 7 && position <= 10) begin
                                field_id <= {field_id[11:0], nibble};
                                if (!is_hex)
                                    valid <= 0;
                            end else if (position >= 12 && position <= 15) begin
                                field_crc <= {field_crc[11:0], nibble};
                                if (!is_hex)
                                    valid <= 0;
                            end else if (position >= 17 && position <= 20) begin
                                field_name <= {field_name[11:0], nibble};
                                if (!is_hex)
                                    valid <= 0;
                            end else if (position == 11 || position == 16 || position == 21) begin
                                if (byte_data != " ")
                                    valid <= 0;
                            end else if (position == 22) begin
                                parsed_kind <= byte_data == "1" ? 1 : byte_data == "2" ? 2 : 0;
                            end else
                                valid <= 0;
                        end
                        2: begin
                            if (position < 4) begin
                                if (lower != literal(2, position, 0))
                                    valid <= 0;
                            end else if (position <= 7) begin
                                row_field <= {row_field[11:0], nibble};
                                if (!is_hex)
                                    valid <= 0;
                            end else if (position == 8) begin
                                if (byte_data != " " || !uploading || display_visible ||
                                    row_field != {7'd0, row_expected})
                                    valid <= 0;
                            end else if (position <= 108) begin
                                if (!is_hex)
                                    valid <= 0;
                                if (position[0])
                                    high_nibble <= nibble;
                                else if (valid && is_hex && uploading && write_pointer < 15200)
                                begin
                                    mask_write    <= 1;
                                    mask_address  <= write_pointer;
                                    mask_data     <= {high_nibble, nibble};
                                    write_pointer <= write_pointer + 1'b1;
                                    crc           <= crc16(crc, {high_nibble, nibble});
                                end
                            end else
                                valid <= 0;
                        end
                        3: begin
                            if (position == 1 && lower == "o")
                                command <= 4;
                            else if (position == 5) begin
                                if (lower == "o")
                                    parsed_kind <= 2;
                                else if (lower != "p")
                                    valid <= 0;
                            end else if (position < 12) begin
                                if (lower != literal(3, position, parsed_kind))
                                    valid <= 0;
                            end else if (position == 12) begin
                                if (byte_data != 34)
                                    valid <= 0;
                                crc <= 16'hffff;
                            end else if (!closed) begin
                                if (byte_data == 34)
                                    closed <= 1;
                                else if (byte_data < 32 || name_bytes >= 64)
                                    valid <= 0;
                                else begin
                                    crc        <= crc16(crc, byte_data);
                                    name_bytes <= name_bytes + 1'b1;
                                end
                            end else
                                valid <= 0;
                        end
                        4:
                            if (position >= 5 || lower != literal(4, position, 0))
                                valid <= 0;
                        default:
                            ;
                    endcase
                end
            end
        end
endmodule
