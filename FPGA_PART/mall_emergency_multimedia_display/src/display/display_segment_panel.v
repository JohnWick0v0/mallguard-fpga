// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：轮显PIC/VOL/PRD/bRt；应急显示CALL 119/110/120或OFF。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// R3a: 8-digit 7-segment front panel (docs/29). Shows three pages that auto
// rotate every second - picture number, volume, slideshow period - and any
// parameter event forces its page for the hold window. Pin map and drive
// polarity follow the official 2026 demo examples (5_seg_SCAN /
// 18_sd_card_audio): digit selects are active-low one-hot, segments are
// active-low with bit0=A..bit6=G and bit7=decimal point; scan step is 8192
// clock cycles per digit (1.31 ms frame at 50 MHz, same cadence as the demo).
//
// Pages (digit 7 = leftmost):
//   PIC:  _ _ _ _ _ P I C n     n = 1..4
//   VOL:  V O L _ _ _ d d d     volume 0..255 in decimal
//   PRD:  P R D _ _ _ d d S     period seconds and unit
module display_segment_panel
    #(parameter integer CLK_HZ               = 50000000,
        parameter integer SUPPORT_EMERGENCY  = 0,
        parameter integer SUPPORT_BRIGHTNESS = 0,
        parameter integer SCAN_STEP_CYCLES   = 8192,
        parameter integer PAGE_PERIOD_CYCLES = 50000000,
        // 1 s rotation
        parameter integer HOLD_CYCLES = 100000000 // 2 s forced page
    )
    (input wire clk,
        input wire rst_n,
        input wire enable,
        input wire [2:0] emergency_kind,
        input wire [1:0] brightness_level,
        input wire bright_event,
        input wire [1:0] media_id,
        // 0..3
        input wire [7:0] volume,
        // 0..255
        input wire [5:0] period_sec,
        // e.g. 2/5/10/30
        input wire pic_event,
        // pulse: force PIC page
        input wire vol_event,
        // pulse: force VOL page
        input wire prd_event,
        // pulse: force PRD page
        output reg [7:0] seg_n,
        // {dp, g,f,e,d,c,b,a} active low
        output reg [7:0] dig_n // digit select, active low one-hot
    );
    localparam [2:0] PAGE_PIC = 3'd0;
    localparam [2:0] PAGE_VOL = 3'd1;
    localparam [2:0] PAGE_PRD = 3'd2;
    localparam [2:0] PAGE_BRT = 3'd3;

    reg [12:0] scan_cnt;
    reg [31:0] page_timer;
    reg [31:0] hold_timer;
    reg [2:0] page;
    reg holding;

    // -------- page selection: rotate, or hold the forced page --------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            page       <= PAGE_PIC;
            page_timer <= 32'd0;
            hold_timer <= 32'd0;
            holding    <= 1'b0;
        end else if (!(SUPPORT_EMERGENCY && emergency_kind != 0)) begin
            if (SUPPORT_BRIGHTNESS && bright_event) begin
                page       <= PAGE_BRT;
                holding    <= 1;
                hold_timer <= 0;
            end else if (vol_event) begin
                page       <= PAGE_VOL;
                holding    <= 1'b1;
                hold_timer <= 32'd0;
            end else if (prd_event) begin
                page       <= PAGE_PRD;
                holding    <= 1'b1;
                hold_timer <= 32'd0;
            end else if (pic_event) begin
                page       <= PAGE_PIC;
                holding    <= 1'b1;
                hold_timer <= 32'd0;
            end else if (holding) begin
                if (hold_timer >= HOLD_CYCLES) begin
                    holding    <= 1'b0;
                    page_timer <= 32'd0;
                end else begin
                    hold_timer <= hold_timer + 1'b1;
                end
            end else begin
                if (page_timer >= PAGE_PERIOD_CYCLES) begin
                    page_timer <= 32'd0;
                    if (page == (SUPPORT_BRIGHTNESS ? PAGE_BRT : PAGE_PRD))
                        page <= PAGE_PIC;
                    else
                        page <= page + 1'b1;
                end else begin
                    page_timer <= page_timer + 1'b1;
                end
            end
        end
    end

    // -------- decimal conversion (combinational double-dabble) --------
    // volume 0..255 -> three BCD digits; period <= 99 -> two digits
    function [11:0] bcd8;
        input [7:0] v;
        integer i;
        reg [19:0] sh;
        reg [3:0] n0, n1, n2;
        begin
            sh = {v, 12'd0};
            n0 = 4'd0;
            n1 = 4'd0;
            n2 = 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                if (n0 >= 5)
                    n0 = n0 + 3;
                if (n1 >= 5)
                    n1 = n1 + 3;
                if (n2 >= 5)
                    n2 = n2 + 3;
                n2 = {n2[2:0], n1[3]};
                n1 = {n1[2:0], n0[3]};
                n0 = {n0[2:0], sh[19]};
                sh = {sh[18:0], 1'b0};
            end
            bcd8 = {n2, n1, n0};
        end
    endfunction

    wire [7:0] volume_percent     = volume == 255        ? 8'd100
                                      : volume[7:6] == 0 ? 8'd0
                                      : volume[7:6] == 1 ? 8'd25
                                      : volume[7:6] == 2 ? 8'd50
                                                           : 8'd75;
    wire [7:0] brightness_percent = brightness_level == 0   ? 8'd100
                                      : brightness_level == 1 ? 8'd75
                                      : brightness_level == 2 ? 8'd50
                                                              : 8'd25;
    wire [11:0] vol_bcd           = bcd8(SUPPORT_BRIGHTNESS ? volume_percent : volume);
    wire [11:0] brt_bcd           = bcd8(brightness_percent);
    wire [3:0] prd_tens           = (period_sec >= 50)   ? 4'd5
                                      : (period_sec >= 40) ? 4'd4
                                      : (period_sec >= 30) ? 4'd3
                                      : (period_sec >= 20) ? 4'd2
                                      : (period_sec >= 10) ? 4'd1
                                                           : 4'd0;
    wire [3:0] prd_ones           = (period_sec >= 50)   ? (period_sec - 6'd50)
                                      : (period_sec >= 40) ? (period_sec - 6'd40)
                                      : (period_sec >= 30) ? (period_sec - 6'd30)
                                      : (period_sec >= 20) ? (period_sec - 6'd20)
                                      : (period_sec >= 10) ? (period_sec - 6'd10)
                                                           : {2'b0, period_sec[3:0]};

    // -------- active-high 7-seg font (bit0=A..bit6=G) --------
    function [6:0] seg_font;
        input [4:0] sym;
        begin
            case (sym)
                5'd0:
                    seg_font = 7'h3f;
                5'd1:
                    seg_font = 7'h06;
                5'd2:
                    seg_font = 7'h5b;
                5'd3:
                    seg_font = 7'h4f;
                5'd4:
                    seg_font = 7'h66;
                5'd5:
                    seg_font = 7'h6d;
                5'd6:
                    seg_font = 7'h7d;
                5'd7:
                    seg_font = 7'h07;
                5'd8:
                    seg_font = 7'h7f;
                5'd9:
                    seg_font = 7'h6f;
                5'h10 + 0:
                    seg_font = 7'h00; // blank
                5'h10 + 1:
                    seg_font = 7'h73; // P
                5'h10 + 2:
                    seg_font = 7'h06; // I
                5'h10 + 3:
                    seg_font = 7'h39; // C
                5'h10 + 4:
                    seg_font = 7'h3e; // V
                5'h10 + 5:
                    seg_font = 7'h38; // L
                5'h10 + 6:
                    seg_font = 7'h50; // R
                5'h10 + 7:
                    seg_font = 7'h5e; // d
                5'h10 + 8:
                    seg_font = 7'h6d; // S
                5'h19:
                    seg_font = 7'h71; // F
                5'h1a:
                    seg_font = 7'h77; // A
                5'h1b:
                    seg_font = 7'h7c; // b
                5'h1c:
                    seg_font = 7'h78; // t
                default:
                    seg_font = 7'h00;
            endcase
        end
    endfunction

    localparam [4:0] F_BLANK = 5'h10;
    localparam [4:0] F_P     = 5'h11;
    localparam [4:0] F_I     = 5'h12;
    localparam [4:0] F_C     = 5'h13;
    localparam [4:0] F_V     = 5'h14;
    localparam [4:0] F_L     = 5'h15;
    localparam [4:0] F_R     = 5'h16;
    localparam [4:0] F_D     = 5'h17;
    localparam [4:0] F_S     = 5'h18;

    // digit 0 = rightmost .. digit 7 = leftmost
    reg [4:0] symbols[0:7];
    integer d;
    always @* begin
        for (d = 0; d < 8; d = d + 1)
            symbols[d] = F_BLANK;
        case (page)
            PAGE_PIC: begin
                symbols[3] = F_P;
                symbols[2] = F_I;
                symbols[1] = F_C;
                symbols[0] = {1'b0, media_id} + 5'd1;
            end
            PAGE_VOL: begin
                symbols[7] = F_V;
                symbols[6] = 5'd0; // 'O' shares the zero glyph (0x3f)
                symbols[5] = F_L;
                symbols[2] = {1'b0, vol_bcd[11:8]};
                symbols[1] = {1'b0, vol_bcd[7:4]};
                symbols[0] = {1'b0, vol_bcd[3:0]};
            end
            PAGE_PRD: begin
                symbols[7] = F_P;
                symbols[6] = F_R;
                symbols[5] = F_D;
                symbols[2] = prd_tens;
                symbols[1] = prd_ones;
                symbols[0] = F_S;
            end
            PAGE_BRT: begin
                symbols[7] = 5'h1b;
                symbols[6] = F_R;
                symbols[5] = 5'h1c;
                symbols[2] = {1'b0, brt_bcd[11:8]};
                symbols[1] = {1'b0, brt_bcd[7:4]};
                symbols[0] = {1'b0, brt_bcd[3:0]};
            end
            default:
                ;
        endcase
        if (SUPPORT_EMERGENCY && emergency_kind != 0) begin
            for (d = 0; d < 8; d = d + 1)
                symbols[d] = F_BLANK;
            if (emergency_kind == 2) begin
                symbols[2] = 0;
                symbols[1] = 5'h19;
                symbols[0] = 5'h19;
            end else begin
                symbols[7] = F_C;
                symbols[6] = 5'h1a;
                symbols[5] = F_L;
                symbols[4] = F_L;
                symbols[2] = 1;
                symbols[1] = emergency_kind == 4 ? 2 : 1;
                symbols[0] = emergency_kind == 1 ? 9 : 0;
            end
        end
    end

    // -------- scan driver --------
    reg [2:0] scan_idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_cnt <= 13'd0;
            scan_idx <= 3'd0;
            dig_n    <= 8'b1111_1110;
            seg_n    <= 8'hff;
        end else if (!enable) begin
            dig_n <= 8'hff;
            seg_n <= 8'hff;
        end else begin
            if (scan_cnt == SCAN_STEP_CYCLES - 1) begin
                scan_cnt <= 13'd0;
                scan_idx <= scan_idx + 1'b1;
            end else begin
                scan_cnt <= scan_cnt + 1'b1;
            end
            dig_n <= ~(8'b0000_0001 << scan_idx);
            seg_n <= {1'b1, ~seg_font(symbols[scan_idx])};
        end
    end
endmodule
