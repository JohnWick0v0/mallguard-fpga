// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：绘制P、M、T、V、L、E与数字的深蓝色状态点阵。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

module status_glyph_renderer #(
    parameter integer SUPPORT_LIVE_PERIOD = 0,
    parameter integer OSD_X             = 8,
    parameter integer OSD_Y             = 8
)(
    input wire        clk,
    input wire        rst_n,
    input wire        frame_start,
    input wire [1:0]  active_index,
    input wire        auto_enabled,
    input wire [7:0]  error_code,
    input wire [5:0]  period_seconds,
    input wire [1:0]  period_sel,
    input wire [2:0]  volume_sel,
    input wire [1:0]  brightness_sel,
    input wire        in_de,
    input wire [11:0] in_rgb,
    input wire [11:0] pixel_x,
    input wire [11:0] pixel_y,
    output reg [11:0] out_rgb,
    output reg        out_de,
    output wire       osd_pixel
);
    reg [1:0] index_q;
    reg auto_q;
    reg [7:0] error_q;
    reg [1:0] period_q;
    reg [5:0] seconds_q;
    reg [2:0] volume_q;
    reg [1:0] brightness_q;
    reg osd_hit;
    reg [4:0] char_value;
    reg [2:0] char_row;
    reg [2:0] char_col;
    reg [4:0] glyph_row;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index_q      <= 2'd0;
            auto_q       <= 1'b0;
            error_q      <= 8'd0;
            seconds_q    <= 5;
            period_q     <= 2'd1;
            volume_q     <= 3'd4;
            brightness_q <= 2'd0;
        end else if (frame_start) begin
            index_q      <= active_index;
            auto_q       <= auto_enabled;
            error_q      <= error_code;
            seconds_q    <= period_seconds;
            period_q     <= period_sel;
            volume_q     <= volume_sel;
            brightness_q <= brightness_sel;
        end
    end

    function [4:0] font_row;
        input [4:0] value;
        input [2:0] row;
        begin
            case (value)
                4'h0:
                    case (row)
                        0:
                            font_row = 5'b11111;
                        1:
                            font_row = 5'b10001;
                        2:
                            font_row = 5'b10001;
                        3:
                            font_row = 5'b10001;
                        4:
                            font_row = 5'b10001;
                        5:
                            font_row = 5'b10001;
                        default:
                            font_row = 5'b11111;
                    endcase
                4'h1:
                    case (row)
                        0:
                            font_row = 5'b00100;
                        1:
                            font_row = 5'b01100;
                        2:
                            font_row = 5'b00100;
                        3:
                            font_row = 5'b00100;
                        4:
                            font_row = 5'b00100;
                        5:
                            font_row = 5'b00100;
                        default:
                            font_row = 5'b11111;
                    endcase
                4'h2:
                    case (row)
                        0:
                            font_row = 5'b11111;
                        1:
                            font_row = 5'b00001;
                        2:
                            font_row = 5'b00001;
                        3:
                            font_row = 5'b11111;
                        4:
                            font_row = 5'b10000;
                        5:
                            font_row = 5'b10000;
                        default:
                            font_row = 5'b11111;
                    endcase
                4'h3:
                    case (row)
                        0:
                            font_row = 5'b11111;
                        1:
                            font_row = 5'b00001;
                        2:
                            font_row = 5'b00001;
                        3:
                            font_row = 5'b11111;
                        4:
                            font_row = 5'b00001;
                        5:
                            font_row = 5'b00001;
                        default:
                            font_row = 5'b11111;
                    endcase
                4'h4:
                    case (row)
                        0:
                            font_row = 5'b10001;
                        1:
                            font_row = 5'b10001;
                        2:
                            font_row = 5'b10001;
                        3:
                            font_row = 5'b11111;
                        4:
                            font_row = 5'b00001;
                        5:
                            font_row = 5'b00001;
                        default:
                            font_row = 5'b00001;
                    endcase
                4'h5:
                    case (row)
                        0:
                            font_row = 5'b11111;
                        1:
                            font_row = 5'b10000;
                        2:
                            font_row = 5'b10000;
                        3:
                            font_row = 5'b11111;
                        4:
                            font_row = 5'b00001;
                        5:
                            font_row = 5'b00001;
                        default:
                            font_row = 5'b11111;
                    endcase
                4'h6:
                    case (row)
                        0:
                            font_row = 5'b11111;
                        1:
                            font_row = 5'b10000;
                        2:
                            font_row = 5'b10000;
                        3:
                            font_row = 5'b11111;
                        4:
                            font_row = 5'b10001;
                        5:
                            font_row = 5'b10001;
                        default:
                            font_row = 5'b11111;
                    endcase
                4'h7:
                    case (row)
                        0:
                            font_row = 5'b11111;
                        1:
                            font_row = 5'b00001;
                        2:
                            font_row = 5'b00010;
                        3:
                            font_row = 5'b00100;
                        4:
                            font_row = 5'b01000;
                        5:
                            font_row = 5'b01000;
                        default:
                            font_row = 5'b01000;
                    endcase
                4'h8:
                    case (row)
                        0:
                            font_row = 5'b11111;
                        1:
                            font_row = 5'b10001;
                        2:
                            font_row = 5'b10001;
                        3:
                            font_row = 5'b11111;
                        4:
                            font_row = 5'b10001;
                        5:
                            font_row = 5'b10001;
                        default:
                            font_row = 5'b11111;
                    endcase
                4'h9:
                    case (row)
                        0:
                            font_row = 5'b11111;
                        1:
                            font_row = 5'b10001;
                        2:
                            font_row = 5'b10001;
                        3:
                            font_row = 5'b11111;
                        4:
                            font_row = 5'b00001;
                        5:
                            font_row = 5'b00001;
                        default:
                            font_row = 5'b11111;
                    endcase
                4'ha:
                    case (row)
                        0:
                            font_row = 5'b01110;
                        1:
                            font_row = 5'b10001;
                        2:
                            font_row = 5'b10001;
                        3:
                            font_row = 5'b11111;
                        4:
                            font_row = 5'b10001;
                        5:
                            font_row = 5'b10001;
                        default:
                            font_row = 5'b10001;
                    endcase
                4'hb:
                    case (row)
                        0:
                            font_row = 5'b10000;
                        1:
                            font_row = 5'b10000;
                        2:
                            font_row = 5'b11110;
                        3:
                            font_row = 5'b10001;
                        4:
                            font_row = 5'b10001;
                        5:
                            font_row = 5'b10001;
                        default:
                            font_row = 5'b11110;
                    endcase
                4'hc:
                    case (row)
                        0:
                            font_row = 5'b01111;
                        1:
                            font_row = 5'b10000;
                        2:
                            font_row = 5'b10000;
                        3:
                            font_row = 5'b10000;
                        4:
                            font_row = 5'b10000;
                        5:
                            font_row = 5'b10000;
                        default:
                            font_row = 5'b01111;
                    endcase
                4'hd:
                    case (row)
                        0:
                            font_row = 5'b00001;
                        1:
                            font_row = 5'b00001;
                        2:
                            font_row = 5'b01111;
                        3:
                            font_row = 5'b10001;
                        4:
                            font_row = 5'b10001;
                        5:
                            font_row = 5'b10001;
                        default:
                            font_row = 5'b01111;
                    endcase
                4'he:
                    case (row)
                        0:
                            font_row = 5'b11111;
                        1:
                            font_row = 5'b10000;
                        2:
                            font_row = 5'b10000;
                        3:
                            font_row = 5'b11110;
                        4:
                            font_row = 5'b10000;
                        5:
                            font_row = 5'b10000;
                        default:
                            font_row = 5'b11111;
                    endcase
                4'hf:
                    case (row)
                        0:
                            font_row = 5'b11111;
                        1:
                            font_row = 5'b10000;
                        2:
                            font_row = 5'b10000;
                        3:
                            font_row = 5'b11110;
                        4:
                            font_row = 5'b10000;
                        5:
                            font_row = 5'b10000;
                        default:
                            font_row = 5'b10000;
                    endcase
                5'h10:
                    case (row)
                        0:
                            font_row = 5'b11111;
                        1:
                            font_row = 5'b00100;
                        2:
                            font_row = 5'b00100;
                        3:
                            font_row = 5'b00100;
                        4:
                            font_row = 5'b00100;
                        5:
                            font_row = 5'b00100;
                        default:
                            font_row = 5'b00100;
                    endcase // T
                5'h11:
                    case (row)
                        0:
                            font_row = 5'b10001;
                        1:
                            font_row = 5'b10001;
                        2:
                            font_row = 5'b10001;
                        3:
                            font_row = 5'b10001;
                        4:
                            font_row = 5'b10001;
                        5:
                            font_row = 5'b01010;
                        default:
                            font_row = 5'b00100;
                    endcase // V
                5'h12:
                    case (row)
                        0:
                            font_row = 5'b11110;
                        1:
                            font_row = 5'b10001;
                        2:
                            font_row = 5'b10001;
                        3:
                            font_row = 5'b11110;
                        4:
                            font_row = 5'b10000;
                        5:
                            font_row = 5'b10000;
                        default:
                            font_row = 5'b10000;
                    endcase // P
                5'h13:
                    case (row)
                        0:
                            font_row = 5'b10001;
                        1:
                            font_row = 5'b11011;
                        2:
                            font_row = 5'b10101;
                        3:
                            font_row = 5'b10101;
                        4:
                            font_row = 5'b10001;
                        5:
                            font_row = 5'b10001;
                        default:
                            font_row = 5'b10001;
                    endcase // M
                5'h14:
                    case (row)
                        0:
                            font_row = 5'b10000;
                        1:
                            font_row = 5'b10000;
                        2:
                            font_row = 5'b10000;
                        3:
                            font_row = 5'b10000;
                        4:
                            font_row = 5'b10000;
                        5:
                            font_row = 5'b10000;
                        default:
                            font_row = 5'b11111;
                    endcase // L
                default:
                    font_row = 5'b00000;
            endcase
        end
    endfunction

    always @* begin
        osd_hit    = 1'b0;
        char_value = 5'h1f;
        char_row   = pixel_y - OSD_Y;
        char_col   = pixel_x - OSD_X;
        glyph_row  = 5'b00000;
        if (pixel_x >= OSD_X && pixel_x < OSD_X + 184 && pixel_y >= OSD_Y && pixel_y < OSD_Y + 8)
        begin
            case ((pixel_x - OSD_X) / 8)
                0:
                    char_value = 5'h12; // P: picture
                1:
                    char_value = {2'b00, index_q} + 5'd1;
                3:
                    char_value = 5'h13; // M: mode
                4:
                    char_value = auto_q ? 5'ha : 5'he;
                6:
                    char_value = 5'h10; // T: slideshow interval in seconds
                7:
                    char_value = SUPPORT_LIVE_PERIOD ? seconds_q / 10
                                 : period_q == 2'd2 || period_q == 2'd3
                                     ? (period_q == 2'd2 ? 5'd1 : 5'd3)
                                     : 5'd0;
                8:
                    char_value = SUPPORT_LIVE_PERIOD ? seconds_q % 10
                                 : period_q == 2'd0  ? 5'd2
                                 : period_q == 2'd1  ? 5'd5
                                                     : 5'd0;
                10:
                    char_value = 5'h11; // V: volume percentage
                11:
                    char_value = volume_q == 3'd4   ? 5'd1
                                 : volume_q == 3'd1 ? 5'd2
                                 : volume_q == 3'd2 ? 5'd5
                                 : volume_q == 3'd3 ? 5'd7
                                                    : 5'd0;
                12:
                    char_value = volume_q == 3'd4                       ? 5'd0
                                 : volume_q == 3'd1 || volume_q == 3'd3 ? 5'd5
                                 : volume_q == 3'd2                     ? 5'd0
                                                                        : 5'h1f;
                13:
                    char_value = volume_q == 3'd4 ? 5'd0 : 5'h1f;
                15:
                    char_value = 5'h14; // L: luminance / brightness
                16:
                    char_value = brightness_q == 2'd0   ? 5'd1
                                 : brightness_q == 2'd1 ? 5'd7
                                 : brightness_q == 2'd2 ? 5'd5
                                                        : 5'd2;
                17:
                    char_value = brightness_q == 2'd0                           ? 5'd0
                                 : brightness_q == 2'd1 || brightness_q == 2'd3 ? 5'd5
                                                                                : 5'd0;
                18:
                    char_value = brightness_q == 2'd0 ? 5'd0 : 5'h1f;
                20:
                    char_value = 5'he; // E: error code
                21:
                    char_value = {1'b0, error_q[7:4]};
                22:
                    char_value = {1'b0, error_q[3:0]};
                default:
                    char_value = 5'h1f;
            endcase
            glyph_row = font_row(char_value, char_row);
            if ((pixel_x - OSD_X) % 8 < 5 && char_row < 7)
                osd_hit = glyph_row[4 - ((pixel_x - OSD_X) % 8)];
        end
        out_de  = in_de;
        out_rgb = in_rgb;
        if (in_de && osd_hit)
            out_rgb = 12'h038;
    end

    assign osd_pixel = osd_hit && in_de;
endmodule
