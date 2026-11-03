// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：绘制加载文字、百分比和进度条；仅显示上层提供的真实状态。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Small combinational overlay: no frame RAM, no extra RGB/sync latency.
module loading_banner (
    input wire         clk,
                       rst_n,
                       vsync,
                       de,
                       enable,
                       failed,
    input wire [9:0]   x,
    input wire [7:0]   progress,
    input wire [23:0]  rgb_in,
    output wire [23:0] rgb_out
);
    reg de_q, vs_q, shown, failure;
    reg [9:0] y;
    reg [7:0] percent;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            de_q    <= 0;
            vs_q    <= 1;
            y       <= 0;
            shown   <= 0;
            failure <= 0;
            percent <= 0;
        end else begin
            de_q <= de;
            vs_q <= vsync;
            if (!vsync)
                y <= 0;
            else if (de_q && !de)
                y <= y + 1'b1;
            if (vs_q && !vsync) begin
                shown   <= enable;
                failure <= failed;
                percent <= progress > 100 ? 100 : progress;
            end
        end
    function [34:0] font;
        input [7:0] c;
        begin
            case (c)
                "E":
                    font = 35'b11111_10000_10000_11110_10000_10000_11111;
                "R":
                    font = 35'b11110_10001_10001_11110_10100_10010_10001;
                "L":
                    font = 35'b10000_10000_10000_10000_10000_10000_11111;
                "O":
                    font = 35'b01110_10001_10001_10001_10001_10001_01110;
                "A":
                    font = 35'b01110_10001_10001_11111_10001_10001_10001;
                "D":
                    font = 35'b11110_10001_10001_10001_10001_10001_11110;
                "I":
                    font = 35'b11111_00100_00100_00100_00100_00100_11111;
                "N":
                    font = 35'b10001_11001_10101_10011_10001_10001_10001;
                "G":
                    font = 35'b01110_10001_10000_10111_10001_10001_01110;
                "0":
                    font = 35'b01110_10001_10011_10101_11001_10001_01110;
                "1":
                    font = 35'b00100_01100_00100_00100_00100_00100_01110;
                "2":
                    font = 35'b01110_10001_00001_00010_00100_01000_11111;
                "3":
                    font = 35'b11110_00001_00001_01110_00001_00001_11110;
                "4":
                    font = 35'b00010_00110_01010_10010_11111_00010_00010;
                "5":
                    font = 35'b11111_10000_10000_11110_00001_00001_11110;
                "6":
                    font = 35'b01110_10000_10000_11110_10001_10001_01110;
                "7":
                    font = 35'b11111_00001_00010_00100_01000_01000_01000;
                "8":
                    font = 35'b01110_10001_10001_01110_10001_10001_01110;
                "9":
                    font = 35'b01110_10001_10001_01111_00001_00001_01110;
                "%":
                    font = 35'b11001_11010_00100_00100_01000_10110_00110;
                default:
                    font = 0;
            endcase
        end
    endfunction
    wire [9:0] rx  = (x - 232) >> 1;
    wire [3:0] row = (y - 386) >> 1;
    reg [7:0] c;
    reg [3:0] tens, ones;
    reg [34:0] bits;
    always @* begin
        tens = percent >= 100  ? 0
               : percent >= 90 ? 9
               : percent >= 80 ? 8
               : percent >= 70 ? 7
               : percent >= 60 ? 6
               : percent >= 50 ? 5
               : percent >= 40 ? 4
               : percent >= 30 ? 3
               : percent >= 20 ? 2
               : percent >= 10 ? 1
                               : 0;
        ones = percent >= 100 ? 0 : percent - tens * 10;
        c    = " ";
        case (rx / 6)
            0:
                c = "L";
            1:
                c = "O";
            2:
                c = "A";
            3:
                c = "D";
            4:
                c = "I";
            5:
                c = "N";
            6:
                c = "G";
            8:
                c = percent == 100 ? "1" : " ";
            9:
                c = (percent >= 10) ? "0" + tens : " ";
            10:
                c = "0" + ones;
            11:
                c = "%";
            default:
                c = " ";
        endcase
        if (failure)
            case (rx / 6)
                0:
                    c = "L";
                1:
                    c = "O";
                2:
                    c = "A";
                3:
                    c = "D";
                5:
                    c = "E";
                6:
                    c = "R";
                7:
                    c = "R";
                8:
                    c = "O";
                9:
                    c = "R";
                default:
                    c = " ";
            endcase
        bits = font(c);
    end
    wire panel        = shown && enable && de && x >= 208 && x < 432 && y >= 376 && y < 420;
    wire ink          = x >= 232 && x < 376 && y >= 386 && y < 400 && rx % 6 < 5 && row < 7 &&
                        bits[34 - row * 5 - (rx % 6)];
    wire track        = x >= 220 && x < 420 && y >= 408 && y < 412;
    wire filled       = track && (x - 220) < ({2'd0, percent} << 1);
    wire border       = x == 208 || x == 431 || y == 376 || y == 419;
    wire [23:0] dim = {(2'b00 + {2'b00, rgb_in[23:18]}) + 8'd8,
                      (2'b00 + {2'b00, rgb_in[15:10]}) + 8'd16,
                      (2'b00 + {2'b00, rgb_in[7:2]}) + 8'd24};
    assign rgb_out    = !panel   ? rgb_in
                        : ink    ? 24'hf2f7ff
                        : filled ? (failure ? 24'he06a60 : 24'h3ed3dc)
                        : track  ? 24'h35465a
                        : border ? 24'h61748b
                                 : dim;
endmodule
