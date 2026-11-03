// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：旧品牌图层兼容阶段；最终普通画面的第三方水印已关闭。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// One-clock registered watermark stage for:
//   米醋电子工作室忧郁
//
// The 12-bit row ROM is forced into block RAM. RGB and every video timing
// signal consumed by the HDMI bridge are delayed by the same single clock,
// so DE/X/sync alignment is preserved while the large font mux is removed
// from the pixel critical path.
module brand_watermark_24
    #(parameter integer ENABLE = 1,
        parameter integer WM_X = 488,
        parameter integer WM_Y = 460,
        // Forensic build tag. 8'h00 keeps the pixel output bit-identical to the
        // legacy behaviour. A non-zero tag modulates the blue-channel LSB of the
        // non-glyph pixels inside the watermark box (bit k of the tag lands on
        // box column k mod 8), which is invisible on a display but decodable
        // from any screenshot row inside the box.
        parameter [7:0] BUILD_ID = 8'h00)
    (input wire clk,
        input wire rst_n,
        input wire hsync,
        input wire vsync,
        input wire de,
        input wire [9:0] pixel_x,
        input wire [11:0] pixel_y,
        input wire [23:0] rgb_in,
        input wire overlay_active_in,
        output reg hsync_out,
        output reg vsync_out,
        output reg de_out,
        output reg [9:0] pixel_x_out,
        output wire [23:0] rgb_out,
        output wire overlay_active_out);
    localparam integer GLYPH_W      = 12;
    localparam integer GLYPH_H      = 12;
    localparam integer GLYPH_STRIDE = 16;
    localparam integer GLYPH_COUNT  = 9;
    localparam integer WM_W         = GLYPH_STRIDE * GLYPH_COUNT;
    localparam [9:0] WM_X_R       = WM_X;

    // 旧品牌图层在产品中ENABLE=0；常量函数保留兼容读取，不再声明悬空ROM。
    function [11:0] glyph_lookup;
        input [7:0] address;
        begin
            case (address)
                8'd0: glyph_lookup = 12'h060;
                8'd1: glyph_lookup = 12'h224;
                8'd2: glyph_lookup = 12'h128;
                8'd3: glyph_lookup = 12'h128;
                8'd4: glyph_lookup = 12'h020;
                8'd5: glyph_lookup = 12'h7FE;
                8'd6: glyph_lookup = 12'h0B0;
                8'd7: glyph_lookup = 12'h1A8;
                8'd8: glyph_lookup = 12'h326;
                8'd9: glyph_lookup = 12'h622;
                8'd10: glyph_lookup = 12'h020;
                8'd11: glyph_lookup = 12'h000;
                8'd12: glyph_lookup = 12'h014;
                8'd13: glyph_lookup = 12'hFD4;
                8'd14: glyph_lookup = 12'h31E;
                8'd15: glyph_lookup = 12'h7D4;
                8'd16: glyph_lookup = 12'h77F;
                8'd17: glyph_lookup = 12'h740;
                8'd18: glyph_lookup = 12'h7DE;
                8'd19: glyph_lookup = 12'h462;
                8'd20: glyph_lookup = 12'h7DE;
                8'd21: glyph_lookup = 12'h462;
                8'd22: glyph_lookup = 12'h7FE;
                8'd23: glyph_lookup = 12'h000;
                8'd24: glyph_lookup = 12'h040;
                8'd25: glyph_lookup = 12'h040;
                8'd26: glyph_lookup = 12'h7FC;
                8'd27: glyph_lookup = 12'h444;
                8'd28: glyph_lookup = 12'h444;
                8'd29: glyph_lookup = 12'h7FC;
                8'd30: glyph_lookup = 12'h444;
                8'd31: glyph_lookup = 12'h7FC;
                8'd32: glyph_lookup = 12'h440;
                8'd33: glyph_lookup = 12'h042;
                8'd34: glyph_lookup = 12'h07E;
                8'd35: glyph_lookup = 12'h000;
                8'd36: glyph_lookup = 12'h3FC;
                8'd37: glyph_lookup = 12'h018;
                8'd38: glyph_lookup = 12'h060;
                8'd39: glyph_lookup = 12'h040;
                8'd40: glyph_lookup = 12'h7FE;
                8'd41: glyph_lookup = 12'h040;
                8'd42: glyph_lookup = 12'h040;
                8'd43: glyph_lookup = 12'h040;
                8'd44: glyph_lookup = 12'h040;
                8'd45: glyph_lookup = 12'h0C0;
                8'd46: glyph_lookup = 12'h000;
                8'd47: glyph_lookup = 12'h000;
                8'd48: glyph_lookup = 12'h7FC;
                8'd49: glyph_lookup = 12'h040;
                8'd50: glyph_lookup = 12'h040;
                8'd51: glyph_lookup = 12'h040;
                8'd52: glyph_lookup = 12'h040;
                8'd53: glyph_lookup = 12'h040;
                8'd54: glyph_lookup = 12'h040;
                8'd55: glyph_lookup = 12'h040;
                8'd56: glyph_lookup = 12'h7FE;
                8'd57: glyph_lookup = 12'h000;
                8'd58: glyph_lookup = 12'h000;
                8'd59: glyph_lookup = 12'h000;
                8'd60: glyph_lookup = 12'h130;
                8'd61: glyph_lookup = 12'h120;
                8'd62: glyph_lookup = 12'h27E;
                8'd63: glyph_lookup = 12'h250;
                8'd64: glyph_lookup = 12'h690;
                8'd65: glyph_lookup = 12'hE1E;
                8'd66: glyph_lookup = 12'h210;
                8'd67: glyph_lookup = 12'h210;
                8'd68: glyph_lookup = 12'h21E;
                8'd69: glyph_lookup = 12'h210;
                8'd70: glyph_lookup = 12'h210;
                8'd71: glyph_lookup = 12'h000;
                8'd72: glyph_lookup = 12'h040;
                8'd73: glyph_lookup = 12'h060;
                8'd74: glyph_lookup = 12'h7FE;
                8'd75: glyph_lookup = 12'h402;
                8'd76: glyph_lookup = 12'h3FC;
                8'd77: glyph_lookup = 12'h088;
                8'd78: glyph_lookup = 12'h3FC;
                8'd79: glyph_lookup = 12'h040;
                8'd80: glyph_lookup = 12'h3FC;
                8'd81: glyph_lookup = 12'h040;
                8'd82: glyph_lookup = 12'h7FE;
                8'd83: glyph_lookup = 12'h000;
                8'd84: glyph_lookup = 12'h200;
                8'd85: glyph_lookup = 12'h214;
                8'd86: glyph_lookup = 12'h214;
                8'd87: glyph_lookup = 12'h6D2;
                8'd88: glyph_lookup = 12'h63C;
                8'd89: glyph_lookup = 12'h628;
                8'd90: glyph_lookup = 12'h228;
                8'd91: glyph_lookup = 12'h228;
                8'd92: glyph_lookup = 12'h228;
                8'd93: glyph_lookup = 12'h24A;
                8'd94: glyph_lookup = 12'h28E;
                8'd95: glyph_lookup = 12'h000;
                8'd96: glyph_lookup = 12'h100;
                8'd97: glyph_lookup = 12'h11E;
                8'd98: glyph_lookup = 12'h7D2;
                8'd99: glyph_lookup = 12'h214;
                8'd100: glyph_lookup = 12'h7D4;
                8'd101: glyph_lookup = 12'hE54;
                8'd102: glyph_lookup = 12'h3D2;
                8'd103: glyph_lookup = 12'h3D2;
                8'd104: glyph_lookup = 12'h252;
                8'd105: glyph_lookup = 12'h254;
                8'd106: glyph_lookup = 12'h2D0;
                8'd107: glyph_lookup = 12'h000;
                8'd108: glyph_lookup = 12'h000;
                8'd109: glyph_lookup = 12'h000;
                8'd110: glyph_lookup = 12'h000;
                8'd111: glyph_lookup = 12'h000;
                8'd112: glyph_lookup = 12'h000;
                8'd113: glyph_lookup = 12'h000;
                8'd114: glyph_lookup = 12'h000;
                8'd115: glyph_lookup = 12'h000;
                8'd116: glyph_lookup = 12'h000;
                8'd117: glyph_lookup = 12'h000;
                8'd118: glyph_lookup = 12'h000;
                8'd119: glyph_lookup = 12'h000;
                8'd120: glyph_lookup = 12'h000;
                8'd121: glyph_lookup = 12'h000;
                8'd122: glyph_lookup = 12'h000;
                8'd123: glyph_lookup = 12'h000;
                8'd124: glyph_lookup = 12'h000;
                8'd125: glyph_lookup = 12'h000;
                8'd126: glyph_lookup = 12'h000;
                8'd127: glyph_lookup = 12'h000;
                8'd128: glyph_lookup = 12'h000;
                8'd129: glyph_lookup = 12'h000;
                8'd130: glyph_lookup = 12'h000;
                8'd131: glyph_lookup = 12'h000;
                8'd132: glyph_lookup = 12'h000;
                8'd133: glyph_lookup = 12'h000;
                8'd134: glyph_lookup = 12'h000;
                8'd135: glyph_lookup = 12'h000;
                8'd136: glyph_lookup = 12'h000;
                8'd137: glyph_lookup = 12'h000;
                8'd138: glyph_lookup = 12'h000;
                8'd139: glyph_lookup = 12'h000;
                8'd140: glyph_lookup = 12'h000;
                8'd141: glyph_lookup = 12'h000;
                8'd142: glyph_lookup = 12'h000;
                8'd143: glyph_lookup = 12'h000;
                default: glyph_lookup = 12'hxxx;
            endcase
        end
    endfunction

    wire watermark_bounds    = (ENABLE != 0) && de && pixel_x >= WM_X && pixel_x < WM_X + WM_W &&
                               pixel_y >= WM_Y && pixel_y < WM_Y + GLYPH_H;
    wire [3:0] glyph_index = (pixel_x - WM_X) >> 4;
    wire [3:0] glyph_col   = (pixel_x - WM_X) & 4'hf;
    wire [3:0] glyph_row_index = pixel_y - WM_Y;
    wire [7:0] glyph_base      = ({4'b0, glyph_index} << 3) + ({4'b0, glyph_index} << 2);
    wire [7:0] glyph_address   = glyph_base + glyph_row_index;

    reg [23:0] rgb_q;
    reg [11:0] glyph_row_q;
    reg [3:0] glyph_col_q;
    reg watermark_bounds_q;
    reg overlay_active_q;
    reg [9:0] box_col_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hsync_out          <= 1'b1;
            vsync_out          <= 1'b1;
            de_out             <= 1'b0;
            pixel_x_out        <= 10'd0;
            rgb_q              <= 24'd0;
            glyph_row_q        <= 12'd0;
            glyph_col_q        <= 4'd0;
            watermark_bounds_q <= 1'b0;
            overlay_active_q   <= 1'b0;
            box_col_q          <= 10'd0;
        end else begin
            hsync_out          <= hsync;
            vsync_out          <= vsync;
            de_out             <= de;
            pixel_x_out        <= pixel_x;
            rgb_q              <= rgb_in;
            glyph_col_q        <= glyph_col;
            watermark_bounds_q <= watermark_bounds && glyph_col < GLYPH_W;
            overlay_active_q   <= overlay_active_in;
            box_col_q          <= pixel_x - WM_X_R;
            if (watermark_bounds && glyph_col < GLYPH_W)
                glyph_row_q <= glyph_lookup(glyph_address);
            else
                glyph_row_q <= 12'd0;
        end
    end

    wire watermark_hit = watermark_bounds_q && glyph_row_q[11 - glyph_col_q];
    wire id_patch_en   = (BUILD_ID != 8'h00) && watermark_bounds_q && !watermark_hit;
    wire id_bit        = BUILD_ID[box_col_q[2:0]];
    assign rgb_out = watermark_hit ? 24'hE8F4FF
                                   : (id_patch_en ? {rgb_q[23:8], rgb_q[7:1], id_bit} : rgb_q);
    assign overlay_active_out = overlay_active_q || watermark_hit;
endmodule
