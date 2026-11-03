// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：商场固定字幕的24像素字形，供滚动字幕查询。
// 时钟：组合查询/透传接口，时序由调用方或子模块确定。
// 复位：本模块无复位端口或本地复位分支。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Generated 22px Microsoft YaHei regular glyphs centered in 24x24 cells, threshold128.
module mall_marquee_glyphs (
    input wire [3:0]  glyph_index,
    input wire [4:0]  glyph_row,
    output reg [23:0] row_bits
);
    wire [8:0] address =
                     ({5'd0, glyph_index} << 4) + ({5'd0, glyph_index} << 3) + {4'd0, glyph_row};
    always @* begin
        case (address)
            9'd1:
                row_bits = 24'h000c00;
            9'd2:
                row_bits = 24'h000c00;
            9'd3:
                row_bits = 24'h3f8800;
            9'd4:
                row_bits = 24'h3f9ffc;
            9'd5:
                row_bits = 24'h009ffc;
            9'd6:
                row_bits = 24'h20900c;
            9'd7:
                row_bits = 24'h31b118;
            9'd8:
                row_bits = 24'h19b118;
            9'd9:
                row_bits = 24'h19a110;
            9'd10:
                row_bits = 24'h0d0300;
            9'd11:
                row_bits = 24'h0f0300;
            9'd12:
                row_bits = 24'h070380;
            9'd13:
                row_bits = 24'h030380;
            9'd14:
                row_bits = 24'h070380;
            9'd15:
                row_bits = 24'h0786c0;
            9'd16:
                row_bits = 24'h0d86c0;
            9'd17:
                row_bits = 24'h0ccc60;
            9'd18:
                row_bits = 24'h18cc60;
            9'd19:
                row_bits = 24'h305830;
            9'd20:
                row_bits = 24'h307018;
            9'd21:
                row_bits = 24'h20e00c;
            9'd22:
                row_bits = 24'h008004;
            9'd25:
                row_bits = 24'h101c00;
            9'd26:
                row_bits = 24'h18fc00;
            9'd27:
                row_bits = 24'h18c000;
            9'd28:
                row_bits = 24'h0cc3fc;
            9'd29:
                row_bits = 24'h04c3fc;
            9'd30:
                row_bits = 24'h00c30c;
            9'd31:
                row_bits = 24'h00c30c;
            9'd32:
                row_bits = 24'h00c30c;
            9'd33:
                row_bits = 24'h7cc30c;
            9'd34:
                row_bits = 24'h3cc30c;
            9'd35:
                row_bits = 24'h0cc30c;
            9'd36:
                row_bits = 24'h0cc30c;
            9'd37:
                row_bits = 24'h0ccb0c;
            9'd38:
                row_bits = 24'h0cfb08;
            9'd39:
                row_bits = 24'h0cf378;
            9'd40:
                row_bits = 24'h0c4370;
            9'd41:
                row_bits = 24'h0c0300;
            9'd42:
                row_bits = 24'h1c0300;
            9'd43:
                row_bits = 24'h360000;
            9'd44:
                row_bits = 24'h63fffc;
            9'd45:
                row_bits = 24'h20fffc;
            9'd50:
                row_bits = 24'h001800;
            9'd51:
                row_bits = 24'h001800;
            9'd52:
                row_bits = 24'h081810;
            9'd53:
                row_bits = 24'h0c1838;
            9'd54:
                row_bits = 24'h0e1870;
            9'd55:
                row_bits = 24'h0618e0;
            9'd56:
                row_bits = 24'h0319c0;
            9'd57:
                row_bits = 24'h011880;
            9'd58:
                row_bits = 24'h001800;
            9'd59:
                row_bits = 24'h3ffffe;
            9'd60:
                row_bits = 24'h3ffffc;
            9'd61:
                row_bits = 24'h008200;
            9'd62:
                row_bits = 24'h008200;
            9'd63:
                row_bits = 24'h018200;
            9'd64:
                row_bits = 24'h018204;
            9'd65:
                row_bits = 24'h038206;
            9'd66:
                row_bits = 24'h030206;
            9'd67:
                row_bits = 24'h0e030c;
            9'd68:
                row_bits = 24'h3c03fc;
            9'd69:
                row_bits = 24'h300060;
            9'd74:
                row_bits = 24'h030400;
            9'd75:
                row_bits = 24'h030c00;
            9'd76:
                row_bits = 24'h330c00;
            9'd77:
                row_bits = 24'h331ffe;
            9'd78:
                row_bits = 24'h331ffc;
            9'd79:
                row_bits = 24'h333300;
            9'd80:
                row_bits = 24'h3361c0;
            9'd81:
                row_bits = 24'h3360c0;
            9'd82:
                row_bits = 24'h334000;
            9'd83:
                row_bits = 24'h330000;
            9'd84:
                row_bits = 24'h333ffc;
            9'd85:
                row_bits = 24'h333ffc;
            9'd86:
                row_bits = 24'h33318c;
            9'd87:
                row_bits = 24'h33318c;
            9'd88:
                row_bits = 24'h33318c;
            9'd89:
                row_bits = 24'h33318c;
            9'd90:
                row_bits = 24'h33318c;
            9'd91:
                row_bits = 24'h33318c;
            9'd92:
                row_bits = 24'h033ffc;
            9'd93:
                row_bits = 24'h033ffc;
            9'd121:
                row_bits = 24'h001000;
            9'd122:
                row_bits = 24'h001800;
            9'd123:
                row_bits = 24'h000c00;
            9'd124:
                row_bits = 24'h3ffffc;
            9'd125:
                row_bits = 24'h3ffffc;
            9'd126:
                row_bits = 24'h30000c;
            9'd127:
                row_bits = 24'h30200c;
            9'd128:
                row_bits = 24'h006000;
            9'd129:
                row_bits = 24'h00c000;
            9'd130:
                row_bits = 24'h7ffffe;
            9'd131:
                row_bits = 24'h3ffffc;
            9'd132:
                row_bits = 24'h0380c0;
            9'd133:
                row_bits = 24'h030180;
            9'd134:
                row_bits = 24'h070180;
            9'd135:
                row_bits = 24'h038300;
            9'd136:
                row_bits = 24'h00e700;
            9'd137:
                row_bits = 24'h003e00;
            9'd138:
                row_bits = 24'h003e00;
            9'd139:
                row_bits = 24'h00f380;
            9'd140:
                row_bits = 24'h03c0e0;
            9'd141:
                row_bits = 24'h1f0078;
            9'd142:
                row_bits = 24'h180010;
            9'd146:
                row_bits = 24'h001800;
            9'd147:
                row_bits = 24'h003c00;
            9'd148:
                row_bits = 24'h006600;
            9'd149:
                row_bits = 24'h00c300;
            9'd150:
                row_bits = 24'h018180;
            9'd151:
                row_bits = 24'h0700e0;
            9'd152:
                row_bits = 24'h1e0078;
            9'd153:
                row_bits = 24'h38001c;
            9'd154:
                row_bits = 24'h27ffe4;
            9'd155:
                row_bits = 24'h07ffe0;
            9'd156:
                row_bits = 24'h001800;
            9'd157:
                row_bits = 24'h001800;
            9'd158:
                row_bits = 24'h001800;
            9'd159:
                row_bits = 24'h0ffff0;
            9'd160:
                row_bits = 24'h07fff0;
            9'd161:
                row_bits = 24'h001800;
            9'd162:
                row_bits = 24'h001800;
            9'd163:
                row_bits = 24'h001800;
            9'd164:
                row_bits = 24'h3ffffc;
            9'd165:
                row_bits = 24'h1ffff8;
            9'd169:
                row_bits = 24'h000400;
            9'd170:
                row_bits = 24'h3fc400;
            9'd171:
                row_bits = 24'h3fcc00;
            9'd172:
                row_bits = 24'h30cffc;
            9'd173:
                row_bits = 24'h36dffc;
            9'd174:
                row_bits = 24'h36d80c;
            9'd175:
                row_bits = 24'h36f20c;
            9'd176:
                row_bits = 24'h36f60c;
            9'd177:
                row_bits = 24'h36c60c;
            9'd178:
                row_bits = 24'h36c40c;
            9'd179:
                row_bits = 24'h36cc8c;
            9'd180:
                row_bits = 24'h36cc8c;
            9'd181:
                row_bits = 24'h36c8cc;
            9'd182:
                row_bits = 24'h36d8cc;
            9'd183:
                row_bits = 24'h36dfec;
            9'd184:
                row_bits = 24'h061e6c;
            9'd185:
                row_bits = 24'h0f000c;
            9'd186:
                row_bits = 24'h098008;
            9'd187:
                row_bits = 24'h18c218;
            9'd188:
                row_bits = 24'h3043f8;
            9'd189:
                row_bits = 24'h200060;
            9'd193:
                row_bits = 24'h060800;
            9'd194:
                row_bits = 24'h060800;
            9'd195:
                row_bits = 24'h161800;
            9'd196:
                row_bits = 24'h361800;
            9'd197:
                row_bits = 24'h363ffc;
            9'd198:
                row_bits = 24'h3fbffc;
            9'd199:
                row_bits = 24'h36664c;
            9'd200:
                row_bits = 24'h26664c;
            9'd201:
                row_bits = 24'h66444c;
            9'd202:
                row_bits = 24'h2604cc;
            9'd203:
                row_bits = 24'h068ccc;
            9'd204:
                row_bits = 24'h0788c8;
            9'd205:
                row_bits = 24'h1e1888;
            9'd206:
                row_bits = 24'h7e1188;
            9'd207:
                row_bits = 24'h263108;
            9'd208:
                row_bits = 24'h066308;
            9'd209:
                row_bits = 24'h064608;
            9'd210:
                row_bits = 24'h060618;
            9'd211:
                row_bits = 24'h060c18;
            9'd212:
                row_bits = 24'h0639f0;
            9'd213:
                row_bits = 24'h0621e0;
            9'd241:
                row_bits = 24'h0200c0;
            9'd242:
                row_bits = 24'h0181c0;
            9'd243:
                row_bits = 24'h01c380;
            9'd244:
                row_bits = 24'h008300;
            9'd245:
                row_bits = 24'h3ffffc;
            9'd246:
                row_bits = 24'h001800;
            9'd247:
                row_bits = 24'h001800;
            9'd248:
                row_bits = 24'h1ffff8;
            9'd249:
                row_bits = 24'h001800;
            9'd250:
                row_bits = 24'h001800;
            9'd251:
                row_bits = 24'h3ffffe;
            9'd254:
                row_bits = 24'h001800;
            9'd255:
                row_bits = 24'h3ffffc;
            9'd256:
                row_bits = 24'h003c00;
            9'd257:
                row_bits = 24'h003c00;
            9'd258:
                row_bits = 24'h006600;
            9'd259:
                row_bits = 24'h00c380;
            9'd260:
                row_bits = 24'h0380f0;
            9'd261:
                row_bits = 24'h3e007c;
            9'd262:
                row_bits = 24'h38000c;
            9'd265:
                row_bits = 24'h040000;
            9'd266:
                row_bits = 24'h0c3ffc;
            9'd267:
                row_bits = 24'h0c1ffc;
            9'd268:
                row_bits = 24'h0c0038;
            9'd269:
                row_bits = 24'h7fc070;
            9'd270:
                row_bits = 24'h3fc0e0;
            9'd271:
                row_bits = 24'h18c0c0;
            9'd272:
                row_bits = 24'h188080;
            9'd273:
                row_bits = 24'h188080;
            9'd274:
                row_bits = 24'h18bffe;
            9'd275:
                row_bits = 24'h11bffc;
            9'd276:
                row_bits = 24'h318080;
            9'd277:
                row_bits = 24'h190080;
            9'd278:
                row_bits = 24'h0f0080;
            9'd279:
                row_bits = 24'h070080;
            9'd280:
                row_bits = 24'h078080;
            9'd281:
                row_bits = 24'h0dc080;
            9'd282:
                row_bits = 24'h184080;
            9'd283:
                row_bits = 24'h300180;
            9'd284:
                row_bits = 24'h201f80;
            9'd285:
                row_bits = 24'h000e00;
            9'd289:
                row_bits = 24'h001800;
            9'd290:
                row_bits = 24'h021800;
            9'd291:
                row_bits = 24'h061800;
            9'd292:
                row_bits = 24'h061800;
            9'd293:
                row_bits = 24'h0e1800;
            9'd294:
                row_bits = 24'h0ffff8;
            9'd295:
                row_bits = 24'h1ffff8;
            9'd296:
                row_bits = 24'h381800;
            9'd297:
                row_bits = 24'h301800;
            9'd298:
                row_bits = 24'h201800;
            9'd299:
                row_bits = 24'h001800;
            9'd300:
                row_bits = 24'h001800;
            9'd301:
                row_bits = 24'h0ffff8;
            9'd302:
                row_bits = 24'h0ffff8;
            9'd303:
                row_bits = 24'h001800;
            9'd304:
                row_bits = 24'h001800;
            9'd305:
                row_bits = 24'h001800;
            9'd306:
                row_bits = 24'h001800;
            9'd307:
                row_bits = 24'h001800;
            9'd308:
                row_bits = 24'h7ffffe;
            9'd309:
                row_bits = 24'h3ffffc;
            9'd313:
                row_bits = 24'h10007c;
            9'd314:
                row_bits = 24'h18fffc;
            9'd315:
                row_bits = 24'h0ee300;
            9'd316:
                row_bits = 24'h040300;
            9'd317:
                row_bits = 24'h000300;
            9'd318:
                row_bits = 24'h000300;
            9'd319:
                row_bits = 24'h21fffe;
            9'd320:
                row_bits = 24'h39fffc;
            9'd321:
                row_bits = 24'h1c0300;
            9'd322:
                row_bits = 24'h0c0300;
            9'd323:
                row_bits = 24'h000300;
            9'd324:
                row_bits = 24'h000300;
            9'd325:
                row_bits = 24'h0c7ff8;
            9'd326:
                row_bits = 24'h0c7ff8;
            9'd327:
                row_bits = 24'h0c4018;
            9'd328:
                row_bits = 24'h0c4018;
            9'd329:
                row_bits = 24'h184018;
            9'd330:
                row_bits = 24'h184018;
            9'd331:
                row_bits = 24'h187ff8;
            9'd332:
                row_bits = 24'h307ff8;
            9'd333:
                row_bits = 24'h104018;
            default:
                row_bits = 0;
        endcase
    end
endmodule
