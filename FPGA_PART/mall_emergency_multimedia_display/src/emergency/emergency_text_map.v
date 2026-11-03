// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：映射应急种类、文字位置和固定字符编号。
// 时钟：组合查询/透传接口，时序由调用方或子模块确定。
// 复位：本模块无复位端口或本地复位分支。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
module emergency_text_map (
    input wire [2:0]   mode,
    input wire [5:0]   position,
    input wire [4:0]   row,
    output wire [10:0] address,
    output reg [11:0]  text_width,
    output reg [23:0]  color
);
    reg [6:0] glyph;
    always @* begin
        glyph = 0;
        case ({mode, position})
            9'd0:
                glyph = 7'd0;
            9'd1:
                glyph = 7'd1;
            9'd2:
                glyph = 7'd2;
            9'd3:
                glyph = 7'd3;
            9'd4:
                glyph = 7'd4;
            9'd5:
                glyph = 7'd5;
            9'd6:
                glyph = 7'd6;
            9'd7:
                glyph = 7'd7;
            9'd8:
                glyph = 7'd8;
            9'd9:
                glyph = 7'd4;
            9'd10:
                glyph = 7'd9;
            9'd11:
                glyph = 7'd10;
            9'd12:
                glyph = 7'd11;
            9'd13:
                glyph = 7'd12;
            9'd64:
                glyph = 7'd13;
            9'd65:
                glyph = 7'd14;
            9'd66:
                glyph = 7'd15;
            9'd67:
                glyph = 7'd16;
            9'd68:
                glyph = 7'd4;
            9'd69:
                glyph = 7'd17;
            9'd70:
                glyph = 7'd18;
            9'd71:
                glyph = 7'd19;
            9'd72:
                glyph = 7'd20;
            9'd73:
                glyph = 7'd21;
            9'd74:
                glyph = 7'd4;
            9'd75:
                glyph = 7'd22;
            9'd76:
                glyph = 7'd23;
            9'd77:
                glyph = 7'd24;
            9'd78:
                glyph = 7'd25;
            9'd79:
                glyph = 7'd26;
            9'd80:
                glyph = 7'd27;
            9'd81:
                glyph = 7'd28;
            9'd82:
                glyph = 7'd29;
            9'd83:
                glyph = 7'd30;
            9'd84:
                glyph = 7'd4;
            9'd85:
                glyph = 7'd31;
            9'd86:
                glyph = 7'd32;
            9'd87:
                glyph = 7'd33;
            9'd88:
                glyph = 7'd34;
            9'd89:
                glyph = 7'd35;
            9'd90:
                glyph = 7'd36;
            9'd91:
                glyph = 7'd4;
            9'd92:
                glyph = 7'd37;
            9'd93:
                glyph = 7'd38;
            9'd94:
                glyph = 7'd39;
            9'd95:
                glyph = 7'd40;
            9'd96:
                glyph = 7'd8;
            9'd128:
                glyph = 7'd41;
            9'd129:
                glyph = 7'd35;
            9'd130:
                glyph = 7'd42;
            9'd131:
                glyph = 7'd26;
            9'd132:
                glyph = 7'd4;
            9'd133:
                glyph = 7'd17;
            9'd134:
                glyph = 7'd18;
            9'd135:
                glyph = 7'd19;
            9'd136:
                glyph = 7'd20;
            9'd137:
                glyph = 7'd21;
            9'd138:
                glyph = 7'd4;
            9'd139:
                glyph = 7'd43;
            9'd140:
                glyph = 7'd44;
            9'd141:
                glyph = 7'd45;
            9'd142:
                glyph = 7'd46;
            9'd143:
                glyph = 7'd4;
            9'd144:
                glyph = 7'd47;
            9'd145:
                glyph = 7'd48;
            9'd146:
                glyph = 7'd49;
            9'd147:
                glyph = 7'd50;
            9'd148:
                glyph = 7'd51;
            9'd149:
                glyph = 7'd52;
            9'd150:
                glyph = 7'd25;
            9'd151:
                glyph = 7'd53;
            9'd152:
                glyph = 7'd4;
            9'd153:
                glyph = 7'd54;
            9'd154:
                glyph = 7'd55;
            9'd155:
                glyph = 7'd56;
            9'd156:
                glyph = 7'd35;
            9'd157:
                glyph = 7'd57;
            9'd158:
                glyph = 7'd58;
            9'd192:
                glyph = 7'd59;
            9'd193:
                glyph = 7'd5;
            9'd194:
                glyph = 7'd15;
            9'd195:
                glyph = 7'd16;
            9'd196:
                glyph = 7'd4;
            9'd197:
                glyph = 7'd17;
            9'd198:
                glyph = 7'd60;
            9'd199:
                glyph = 7'd30;
            9'd200:
                glyph = 7'd61;
            9'd201:
                glyph = 7'd62;
            9'd202:
                glyph = 7'd63;
            9'd203:
                glyph = 7'd64;
            9'd204:
                glyph = 7'd4;
            9'd205:
                glyph = 7'd65;
            9'd206:
                glyph = 7'd66;
            9'd207:
                glyph = 7'd67;
            9'd208:
                glyph = 7'd68;
            9'd209:
                glyph = 7'd4;
            9'd210:
                glyph = 7'd18;
            9'd211:
                glyph = 7'd19;
            9'd212:
                glyph = 7'd69;
            9'd213:
                glyph = 7'd70;
            9'd214:
                glyph = 7'd71;
            9'd215:
                glyph = 7'd69;
            9'd216:
                glyph = 7'd4;
            9'd217:
                glyph = 7'd47;
            9'd218:
                glyph = 7'd48;
            9'd219:
                glyph = 7'd49;
            9'd220:
                glyph = 7'd50;
            9'd221:
                glyph = 7'd51;
            9'd222:
                glyph = 7'd52;
            9'd223:
                glyph = 7'd25;
            9'd224:
                glyph = 7'd53;
            9'd256:
                glyph = 7'd72;
            9'd257:
                glyph = 7'd73;
            9'd258:
                glyph = 7'd74;
            9'd259:
                glyph = 7'd75;
            9'd260:
                glyph = 7'd4;
            9'd261:
                glyph = 7'd17;
            9'd262:
                glyph = 7'd18;
            9'd263:
                glyph = 7'd19;
            9'd264:
                glyph = 7'd76;
            9'd265:
                glyph = 7'd77;
            9'd266:
                glyph = 7'd69;
            9'd267:
                glyph = 7'd70;
            9'd268:
                glyph = 7'd71;
            9'd269:
                glyph = 7'd69;
            9'd270:
                glyph = 7'd4;
            9'd271:
                glyph = 7'd78;
            9'd272:
                glyph = 7'd79;
            9'd273:
                glyph = 7'd80;
            9'd274:
                glyph = 7'd81;
            9'd275:
                glyph = 7'd51;
            9'd276:
                glyph = 7'd52;
            9'd277:
                glyph = 7'd17;
            9'd278:
                glyph = 7'd82;
            9'd279:
                glyph = 7'd83;
            9'd280:
                glyph = 7'd49;
            9'd281:
                glyph = 7'd50;
            9'd282:
                glyph = 7'd51;
            9'd283:
                glyph = 7'd52;
            default:
                glyph = 0;
        endcase
    end
    assign address = ({4'd0, glyph} << 4) + ({4'd0, glyph} << 3) + {6'd0, row};
    always @* begin
        case (mode)
            3'd0: begin
                text_width = 12'd448;
                color      = 24'hFFD966;
            end
            3'd1: begin
                text_width = 12'd1056;
                color      = 24'hFFD966;
            end
            3'd2: begin
                text_width = 12'd992;
                color      = 24'hF2F7FF;
            end
            3'd3: begin
                text_width = 12'd1056;
                color      = 24'hC8E6FF;
            end
            3'd4: begin
                text_width = 12'd896;
                color      = 24'hFFE066;
            end
            default: begin
                text_width = 0;
                color      = 0;
            end
        endcase
    end
endmodule
