// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：解析广告、视频、参数、时段与save命令；CR/LF终止有界命令行。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Bounded ASCII line parser. CRLF is required; long/binary finder uploads
// cannot accidentally match a command. No SPI/Flash action is exposed here.
module display_command_decoder (
    input wire       clk,
                     rst_n,
                     byte_valid,
    input wire [7:0] byte_data,
    output reg       valid,
    output reg [3:0] command,
    output reg [7:0] value
);
    reg [63:0] word;
    reg [3:0] length;
    reg digits, bad, has_digit;
    reg [9:0] number;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            word      <= 0;
            length    <= 0;
            digits    <= 0;
            bad       <= 0;
            has_digit <= 0;
            number    <= 0;
            valid     <= 0;
            command   <= 0;
            value     <= 0;
        end else begin
            valid <= 0;
            if (byte_valid) begin
                if (byte_data == 13 || byte_data == 10) begin
                    command <= 0;
                    value   <= number[7:0];
                    if (!bad && length != 0 && (!digits || has_digit)) begin
                        case (word)
                            "video": begin
                                command <= 1;
                                valid   <= !digits;
                            end
                            "ads": begin
                                command <= 2;
                                valid   <= !digits;
                            end
                            "pause": begin
                                command <= 3;
                                valid   <= !digits;
                            end
                            "play": begin
                                command <= 4;
                                valid   <= !digits;
                            end
                            "next": begin
                                command <= 5;
                                valid   <= !digits;
                            end
                            "prev": begin
                                command <= 6;
                                valid   <= !digits;
                            end
                            "auto": begin
                                command <= 7;
                                valid   <= !digits;
                            end
                            "manual": begin
                                command <= 8;
                                valid   <= !digits;
                            end
                            "vol": begin
                                command <= 9;
                                valid   <= digits && (number == 0 || number == 25 || number == 50 ||
                                                         number == 75 || number == 100);
                            end
                            "light": begin
                                command <= 10;
                                valid <= digits && (number == 25 || number == 50 || number == 75 ||
                                                       number == 100);
                            end
                            "interval": begin
                                command <= 11;
                                valid   <= digits && number >= 2 && number <= 60;
                            end
                            "slot": begin
                                command <= 12;
                                valid   <= digits && number <= 3;
                            end
                            "save": begin
                                command <= 13;
                                valid   <= !digits;
                            end
                            default: begin
                                command <= 0;
                                valid   <= 0;
                            end
                        endcase
                    end
                    word      <= 0;
                    length    <= 0;
                    digits    <= 0;
                    bad       <= 0;
                    has_digit <= 0;
                    number    <= 0;
                end else if (!bad) begin
                    if (!digits) begin
                        if (byte_data == 32 && length != 0)
                            digits <= 1;
                        else if (length == 8 || byte_data < 97 || byte_data > 122)
                            bad <= 1;
                        else begin
                            word   <= {word[55:0], byte_data};
                            length <= length + 1'b1;
                        end
                    end else if (byte_data >= 48 && byte_data <= 57 && number <= 100) begin
                        number    <= (number << 3) + (number << 1) + byte_data - 48;
                        has_digit <= 1;
                    end else
                        bad <= 1;
                end
            end
        end
endmodule
