// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：旧火灾字幕字形接口，保留原有兼容逻辑。
// 时钟：组合查询/透传接口，时序由调用方或子模块确定。
// 复位：本模块无复位端口或本地复位分支。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// 火灾警报 请保持冷静 沿疏散指示有序撤离 禁止乘坐电梯
module fire_warning_font_24 (
    input wire [5:0]  glyph_index,
    input wire [4:0]  glyph_row,
    output reg [23:0] row_bits
);
    wire [10:0] address =
                      ({5'd0, glyph_index} << 4) + ({5'd0, glyph_index} << 3) + {6'd0, glyph_row};
    always @* begin
        case (address)
            11'd0:
                row_bits = 24'h001800;
            11'd1:
                row_bits = 24'h001800;
            11'd2:
                row_bits = 24'h001800;
            11'd3:
                row_bits = 24'h001800;
            11'd4:
                row_bits = 24'h001820;
            11'd5:
                row_bits = 24'h061830;
            11'd6:
                row_bits = 24'h0e1830;
            11'd7:
                row_bits = 24'h0c1860;
            11'd8:
                row_bits = 24'h0c3860;
            11'd9:
                row_bits = 24'h1c38e0;
            11'd10:
                row_bits = 24'h183cc0;
            11'd11:
                row_bits = 24'h083c00;
            11'd12:
                row_bits = 24'h003c00;
            11'd13:
                row_bits = 24'h006e00;
            11'd14:
                row_bits = 24'h006600;
            11'd15:
                row_bits = 24'h00c300;
            11'd16:
                row_bits = 24'h01c380;
            11'd17:
                row_bits = 24'h0381e0;
            11'd18:
                row_bits = 24'h0700f0;
            11'd19:
                row_bits = 24'h1e007e;
            11'd20:
                row_bits = 24'h7c001e;
            11'd21:
                row_bits = 24'h380004;
            11'd24:
                row_bits = 24'h001000;
            11'd25:
                row_bits = 24'h003000;
            11'd26:
                row_bits = 24'h003800;
            11'd27:
                row_bits = 24'h001800;
            11'd28:
                row_bits = 24'h3ffffc;
            11'd29:
                row_bits = 24'h3ffffc;
            11'd30:
                row_bits = 24'h30001c;
            11'd31:
                row_bits = 24'h30000c;
            11'd32:
                row_bits = 24'h30180c;
            11'd33:
                row_bits = 24'h001800;
            11'd34:
                row_bits = 24'h061830;
            11'd35:
                row_bits = 24'h063830;
            11'd36:
                row_bits = 24'h0e3870;
            11'd37:
                row_bits = 24'h0c3c60;
            11'd38:
                row_bits = 24'h1c3ce0;
            11'd39:
                row_bits = 24'h087640;
            11'd40:
                row_bits = 24'h00e700;
            11'd41:
                row_bits = 24'h00c380;
            11'd42:
                row_bits = 24'h03c1c0;
            11'd43:
                row_bits = 24'h0700f0;
            11'd44:
                row_bits = 24'h3e007c;
            11'd45:
                row_bits = 24'h3c001c;
            11'd48:
                row_bits = 24'h066080;
            11'd49:
                row_bits = 24'h066180;
            11'd50:
                row_bits = 24'h3ffbfe;
            11'd51:
                row_bits = 24'h0667fe;
            11'd52:
                row_bits = 24'h0e6618;
            11'd53:
                row_bits = 24'h1ffb30;
            11'd54:
                row_bits = 24'h3819b0;
            11'd55:
                row_bits = 24'h7f98f0;
            11'd56:
                row_bits = 24'h79f8f0;
            11'd57:
                row_bits = 24'h1fb7fe;
            11'd58:
                row_bits = 24'h1f9b0c;
            11'd59:
                row_bits = 24'h7ffffe;
            11'd60:
                row_bits = 24'h7ffffe;
            11'd61:
                row_bits = 24'h07ffe0;
            11'd62:
                row_bits = 24'h07ffe0;
            11'd64:
                row_bits = 24'h07ffe0;
            11'd66:
                row_bits = 24'h0ffff0;
            11'd67:
                row_bits = 24'h060030;
            11'd68:
                row_bits = 24'h07fff0;
            11'd69:
                row_bits = 24'h07fff0;
            11'd70:
                row_bits = 24'h040020;
            11'd72:
                row_bits = 24'h060000;
            11'd73:
                row_bits = 24'h061ff0;
            11'd74:
                row_bits = 24'h061ff8;
            11'd75:
                row_bits = 24'h061818;
            11'd76:
                row_bits = 24'h061818;
            11'd77:
                row_bits = 24'h061818;
            11'd78:
                row_bits = 24'h7fd838;
            11'd79:
                row_bits = 24'h26d8f0;
            11'd80:
                row_bits = 24'h0618e0;
            11'd81:
                row_bits = 24'h061ff8;
            11'd82:
                row_bits = 24'h065ff8;
            11'd83:
                row_bits = 24'h07de18;
            11'd84:
                row_bits = 24'h7f1b18;
            11'd85:
                row_bits = 24'h7e1b30;
            11'd86:
                row_bits = 24'h061bb0;
            11'd87:
                row_bits = 24'h0619f0;
            11'd88:
                row_bits = 24'h0619e0;
            11'd89:
                row_bits = 24'h0618e0;
            11'd90:
                row_bits = 24'h0619f0;
            11'd91:
                row_bits = 24'h061bbc;
            11'd92:
                row_bits = 24'h1e1f1e;
            11'd93:
                row_bits = 24'h1c1e06;
            11'd120:
                row_bits = 24'h000100;
            11'd121:
                row_bits = 24'h100300;
            11'd122:
                row_bits = 24'h187ffc;
            11'd123:
                row_bits = 24'h0c7ffc;
            11'd124:
                row_bits = 24'h060300;
            11'd125:
                row_bits = 24'h067ffc;
            11'd126:
                row_bits = 24'h003ff8;
            11'd127:
                row_bits = 24'h000300;
            11'd128:
                row_bits = 24'h7cfffe;
            11'd129:
                row_bits = 24'h7cfffe;
            11'd130:
                row_bits = 24'h0c0000;
            11'd131:
                row_bits = 24'h0c3ff8;
            11'd132:
                row_bits = 24'h0c3018;
            11'd133:
                row_bits = 24'h0c3018;
            11'd134:
                row_bits = 24'h0c3ff8;
            11'd135:
                row_bits = 24'h0c3018;
            11'd136:
                row_bits = 24'h0db018;
            11'd137:
                row_bits = 24'h0f3ff8;
            11'd138:
                row_bits = 24'h0e3018;
            11'd139:
                row_bits = 24'h1c3018;
            11'd140:
                row_bits = 24'h083038;
            11'd141:
                row_bits = 24'h003038;
            11'd145:
                row_bits = 24'h073ff0;
            11'd146:
                row_bits = 24'h063ff0;
            11'd147:
                row_bits = 24'h063030;
            11'd148:
                row_bits = 24'h0e3030;
            11'd149:
                row_bits = 24'h0c3030;
            11'd150:
                row_bits = 24'h1c3030;
            11'd151:
                row_bits = 24'h1c3ff0;
            11'd152:
                row_bits = 24'h3c3ff0;
            11'd153:
                row_bits = 24'h3c0300;
            11'd154:
                row_bits = 24'h6c0300;
            11'd155:
                row_bits = 24'h6cfffc;
            11'd156:
                row_bits = 24'h0dfffe;
            11'd157:
                row_bits = 24'h0c0fc0;
            11'd158:
                row_bits = 24'h0c1bc0;
            11'd159:
                row_bits = 24'h0c1b60;
            11'd160:
                row_bits = 24'h0c3370;
            11'd161:
                row_bits = 24'h0c6338;
            11'd162:
                row_bits = 24'h0ce31e;
            11'd163:
                row_bits = 24'h0dc30e;
            11'd164:
                row_bits = 24'h0c8300;
            11'd165:
                row_bits = 24'h0c0300;
            11'd169:
                row_bits = 24'h060380;
            11'd170:
                row_bits = 24'h060380;
            11'd171:
                row_bits = 24'h060380;
            11'd172:
                row_bits = 24'h063ff8;
            11'd173:
                row_bits = 24'h2ebff8;
            11'd174:
                row_bits = 24'h7f8380;
            11'd175:
                row_bits = 24'h2f8380;
            11'd176:
                row_bits = 24'h060380;
            11'd177:
                row_bits = 24'h067ffe;
            11'd178:
                row_bits = 24'h06a074;
            11'd179:
                row_bits = 24'h078060;
            11'd180:
                row_bits = 24'h1f0060;
            11'd181:
                row_bits = 24'h7e7ffe;
            11'd182:
                row_bits = 24'h763ffe;
            11'd183:
                row_bits = 24'h061060;
            11'd184:
                row_bits = 24'h063860;
            11'd185:
                row_bits = 24'h061c60;
            11'd186:
                row_bits = 24'h060c60;
            11'd187:
                row_bits = 24'h060860;
            11'd188:
                row_bits = 24'h3e01e0;
            11'd189:
                row_bits = 24'h3c01e0;
            11'd193:
                row_bits = 24'h000700;
            11'd194:
                row_bits = 24'h000700;
            11'd195:
                row_bits = 24'h300f00;
            11'd196:
                row_bits = 24'h380d80;
            11'd197:
                row_bits = 24'h1c18c0;
            11'd198:
                row_bits = 24'h0e38e0;
            11'd199:
                row_bits = 24'h043670;
            11'd200:
                row_bits = 24'h00e73c;
            11'd201:
                row_bits = 24'h01c31e;
            11'd202:
                row_bits = 24'h058184;
            11'd203:
                row_bits = 24'h060000;
            11'd204:
                row_bits = 24'h0cfff8;
            11'd205:
                row_bits = 24'h0cfff0;
            11'd206:
                row_bits = 24'h180070;
            11'd207:
                row_bits = 24'h1800e0;
            11'd208:
                row_bits = 24'h3018c0;
            11'd209:
                row_bits = 24'h701d80;
            11'd210:
                row_bits = 24'h600f80;
            11'd211:
                row_bits = 24'h000700;
            11'd212:
                row_bits = 24'h0003c0;
            11'd213:
                row_bits = 24'h0001c0;
            11'd216:
                row_bits = 24'h000200;
            11'd217:
                row_bits = 24'h060300;
            11'd218:
                row_bits = 24'h060600;
            11'd219:
                row_bits = 24'h7fe7f0;
            11'd220:
                row_bits = 24'h060ff0;
            11'd221:
                row_bits = 24'h060c60;
            11'd222:
                row_bits = 24'h3fd860;
            11'd223:
                row_bits = 24'h061ffc;
            11'd224:
                row_bits = 24'h7feffc;
            11'd225:
                row_bits = 24'h7fe08c;
            11'd226:
                row_bits = 24'h00008c;
            11'd227:
                row_bits = 24'h3fcffe;
            11'd228:
                row_bits = 24'h3fcffe;
            11'd229:
                row_bits = 24'h30c08c;
            11'd230:
                row_bits = 24'h3fc08c;
            11'd231:
                row_bits = 24'h3fcffc;
            11'd232:
                row_bits = 24'h30cffc;
            11'd233:
                row_bits = 24'h3fc088;
            11'd234:
                row_bits = 24'h3fc080;
            11'd235:
                row_bits = 24'h30c080;
            11'd236:
                row_bits = 24'h31c780;
            11'd237:
                row_bits = 24'h31c780;
            11'd265:
                row_bits = 24'h180000;
            11'd266:
                row_bits = 24'h1c1ff0;
            11'd267:
                row_bits = 24'h0e1fe0;
            11'd268:
                row_bits = 24'h061860;
            11'd269:
                row_bits = 24'h001860;
            11'd270:
                row_bits = 24'h001860;
            11'd271:
                row_bits = 24'h301870;
            11'd272:
                row_bits = 24'h7c387e;
            11'd273:
                row_bits = 24'h1e703e;
            11'd274:
                row_bits = 24'h04e000;
            11'd275:
                row_bits = 24'h004000;
            11'd276:
                row_bits = 24'h003ff8;
            11'd277:
                row_bits = 24'h063ff8;
            11'd278:
                row_bits = 24'h063018;
            11'd279:
                row_bits = 24'h0e3018;
            11'd280:
                row_bits = 24'h0c3018;
            11'd281:
                row_bits = 24'h1c3018;
            11'd282:
                row_bits = 24'h183ff8;
            11'd283:
                row_bits = 24'h383ff8;
            11'd284:
                row_bits = 24'h303018;
            11'd285:
                row_bits = 24'h103018;
            11'd286:
                row_bits = 24'h000008;
            11'd289:
                row_bits = 24'h000700;
            11'd290:
                row_bits = 24'h3f8300;
            11'd291:
                row_bits = 24'h3ffffc;
            11'd292:
                row_bits = 24'h037ffc;
            11'd293:
                row_bits = 24'h060600;
            11'd294:
                row_bits = 24'h060e20;
            11'd295:
                row_bits = 24'h060c70;
            11'd296:
                row_bits = 24'h261838;
            11'd297:
                row_bits = 24'h363ffc;
            11'd298:
                row_bits = 24'h37be0c;
            11'd299:
                row_bits = 24'h378000;
            11'd300:
                row_bits = 24'h361b30;
            11'd301:
                row_bits = 24'h361b30;
            11'd302:
                row_bits = 24'h361330;
            11'd303:
                row_bits = 24'h363330;
            11'd304:
                row_bits = 24'h37b330;
            11'd305:
                row_bits = 24'h3fb330;
            11'd306:
                row_bits = 24'h7e3336;
            11'd307:
                row_bits = 24'h706336;
            11'd308:
                row_bits = 24'h00e33e;
            11'd309:
                row_bits = 24'h00c33c;
            11'd313:
                row_bits = 24'h0cc1c0;
            11'd314:
                row_bits = 24'h0cc180;
            11'd315:
                row_bits = 24'h0ce180;
            11'd316:
                row_bits = 24'h7ff380;
            11'd317:
                row_bits = 24'h0cc3fe;
            11'd318:
                row_bits = 24'h0cc3fe;
            11'd319:
                row_bits = 24'h7ff718;
            11'd320:
                row_bits = 24'h7fff18;
            11'd321:
                row_bits = 24'h000f10;
            11'd322:
                row_bits = 24'h1fef30;
            11'd323:
                row_bits = 24'h1fe330;
            11'd324:
                row_bits = 24'h186130;
            11'd325:
                row_bits = 24'h1fe1b0;
            11'd326:
                row_bits = 24'h1fe1f0;
            11'd327:
                row_bits = 24'h1860e0;
            11'd328:
                row_bits = 24'h1fe0e0;
            11'd329:
                row_bits = 24'h1fe0e0;
            11'd330:
                row_bits = 24'h1861f0;
            11'd331:
                row_bits = 24'h18631c;
            11'd332:
                row_bits = 24'h18ee0e;
            11'd333:
                row_bits = 24'h18cc04;
            11'd337:
                row_bits = 24'h063800;
            11'd338:
                row_bits = 24'h063810;
            11'd339:
                row_bits = 24'h0638f8;
            11'd340:
                row_bits = 24'h063ff0;
            11'd341:
                row_bits = 24'h063e00;
            11'd342:
                row_bits = 24'h3fb800;
            11'd343:
                row_bits = 24'h3fb80c;
            11'd344:
                row_bits = 24'h06380c;
            11'd345:
                row_bits = 24'h061ffc;
            11'd346:
                row_bits = 24'h068ff8;
            11'd347:
                row_bits = 24'h078000;
            11'd348:
                row_bits = 24'h1f3ff8;
            11'd349:
                row_bits = 24'h7e3818;
            11'd350:
                row_bits = 24'h663818;
            11'd351:
                row_bits = 24'h063ff8;
            11'd352:
                row_bits = 24'h063ff8;
            11'd353:
                row_bits = 24'h063818;
            11'd354:
                row_bits = 24'h063818;
            11'd355:
                row_bits = 24'h0e3ff8;
            11'd356:
                row_bits = 24'h3c3ff8;
            11'd357:
                row_bits = 24'h3c3818;
            11'd361:
                row_bits = 24'h0ffff0;
            11'd362:
                row_bits = 24'h0ffff0;
            11'd367:
                row_bits = 24'h3ffffc;
            11'd368:
                row_bits = 24'h3ffffe;
            11'd369:
                row_bits = 24'h001800;
            11'd370:
                row_bits = 24'h001800;
            11'd371:
                row_bits = 24'h021800;
            11'd372:
                row_bits = 24'h0318c0;
            11'd373:
                row_bits = 24'h0718e0;
            11'd374:
                row_bits = 24'h061870;
            11'd375:
                row_bits = 24'h0c1830;
            11'd376:
                row_bits = 24'h1c1818;
            11'd377:
                row_bits = 24'h18181c;
            11'd378:
                row_bits = 24'h30180c;
            11'd379:
                row_bits = 24'h00f800;
            11'd380:
                row_bits = 24'h007800;
            11'd381:
                row_bits = 24'h004000;
            11'd385:
                row_bits = 24'h003800;
            11'd386:
                row_bits = 24'h003000;
            11'd387:
                row_bits = 24'h007000;
            11'd388:
                row_bits = 24'h3ffffe;
            11'd389:
                row_bits = 24'h00e000;
            11'd390:
                row_bits = 24'h00e000;
            11'd391:
                row_bits = 24'h01c000;
            11'd392:
                row_bits = 24'h01fff8;
            11'd393:
                row_bits = 24'h038038;
            11'd394:
                row_bits = 24'h078038;
            11'd395:
                row_bits = 24'h0f8038;
            11'd396:
                row_bits = 24'h1dfff8;
            11'd397:
                row_bits = 24'h798038;
            11'd398:
                row_bits = 24'h318038;
            11'd399:
                row_bits = 24'h018038;
            11'd400:
                row_bits = 24'h01fff8;
            11'd401:
                row_bits = 24'h018038;
            11'd402:
                row_bits = 24'h018038;
            11'd403:
                row_bits = 24'h018038;
            11'd404:
                row_bits = 24'h0180f0;
            11'd405:
                row_bits = 24'h0180f0;
            11'd408:
                row_bits = 24'h000c00;
            11'd409:
                row_bits = 24'h000c00;
            11'd410:
                row_bits = 24'h000e00;
            11'd411:
                row_bits = 24'h1ffffe;
            11'd412:
                row_bits = 24'h1ffffc;
            11'd413:
                row_bits = 24'h180000;
            11'd414:
                row_bits = 24'h19fff0;
            11'd415:
                row_bits = 24'h19fff0;
            11'd416:
                row_bits = 24'h1800e0;
            11'd417:
                row_bits = 24'h181fc0;
            11'd418:
                row_bits = 24'h180f00;
            11'd419:
                row_bits = 24'h180700;
            11'd420:
                row_bits = 24'h1bfffc;
            11'd421:
                row_bits = 24'h1bfffc;
            11'd422:
                row_bits = 24'h18061c;
            11'd423:
                row_bits = 24'h180618;
            11'd424:
                row_bits = 24'h380600;
            11'd425:
                row_bits = 24'h300600;
            11'd426:
                row_bits = 24'h300600;
            11'd427:
                row_bits = 24'h700600;
            11'd428:
                row_bits = 24'h603e00;
            11'd429:
                row_bits = 24'h001e00;
            11'd432:
                row_bits = 24'h080000;
            11'd433:
                row_bits = 24'h0c3060;
            11'd434:
                row_bits = 24'h081860;
            11'd435:
                row_bits = 24'h081060;
            11'd436:
                row_bits = 24'h09ff60;
            11'd437:
                row_bits = 24'h7e607e;
            11'd438:
                row_bits = 24'h7e64cc;
            11'd439:
                row_bits = 24'h08cecc;
            11'd440:
                row_bits = 24'h09ffcc;
            11'd441:
                row_bits = 24'h0883cc;
            11'd442:
                row_bits = 24'h0effcc;
            11'd443:
                row_bits = 24'h1efec8;
            11'd444:
                row_bits = 24'h7cc648;
            11'd445:
                row_bits = 24'h78fe58;
            11'd446:
                row_bits = 24'h08fe78;
            11'd447:
                row_bits = 24'h08c678;
            11'd448:
                row_bits = 24'h08fe38;
            11'd449:
                row_bits = 24'h08fe30;
            11'd450:
                row_bits = 24'h08c678;
            11'd451:
                row_bits = 24'h18c6fc;
            11'd452:
                row_bits = 24'h38dfce;
            11'd453:
                row_bits = 24'h308984;
            11'd456:
                row_bits = 24'h001800;
            11'd457:
                row_bits = 24'h001800;
            11'd458:
                row_bits = 24'h3ffffc;
            11'd459:
                row_bits = 24'h3ffffc;
            11'd460:
                row_bits = 24'h000100;
            11'd461:
                row_bits = 24'h01e780;
            11'd462:
                row_bits = 24'h0c7e18;
            11'd463:
                row_bits = 24'h0c7f18;
            11'd464:
                row_bits = 24'h0de3d8;
            11'd465:
                row_bits = 24'h0c8098;
            11'd466:
                row_bits = 24'h0ffff8;
            11'd467:
                row_bits = 24'h0ffff0;
            11'd468:
                row_bits = 24'h003800;
            11'd469:
                row_bits = 24'h1ffffc;
            11'd470:
                row_bits = 24'h3ffffc;
            11'd471:
                row_bits = 24'h30600c;
            11'd472:
                row_bits = 24'h30c18c;
            11'd473:
                row_bits = 24'h3183cc;
            11'd474:
                row_bits = 24'h33ffcc;
            11'd475:
                row_bits = 24'h31e08c;
            11'd476:
                row_bits = 24'h30003c;
            11'd477:
                row_bits = 24'h30003c;
            11'd504:
                row_bits = 24'h010000;
            11'd505:
                row_bits = 24'h0301c0;
            11'd506:
                row_bits = 24'h030080;
            11'd507:
                row_bits = 24'h3feffc;
            11'd508:
                row_bits = 24'h3ffffc;
            11'd509:
                row_bits = 24'h0303e0;
            11'd510:
                row_bits = 24'h07e3e0;
            11'd511:
                row_bits = 24'h0f77f8;
            11'd512:
                row_bits = 24'h1b2c9c;
            11'd513:
                row_bits = 24'h33388e;
            11'd514:
                row_bits = 24'h231180;
            11'd515:
                row_bits = 24'h07ffe0;
            11'd516:
                row_bits = 24'h07fff0;
            11'd518:
                row_bits = 24'h000008;
            11'd519:
                row_bits = 24'h3ffffc;
            11'd520:
                row_bits = 24'h001800;
            11'd521:
                row_bits = 24'h0318c0;
            11'd522:
                row_bits = 24'h0718f0;
            11'd523:
                row_bits = 24'h1e1878;
            11'd524:
                row_bits = 24'h38781c;
            11'd525:
                row_bits = 24'h007800;
            11'd530:
                row_bits = 24'h000c00;
            11'd531:
                row_bits = 24'h000c00;
            11'd532:
                row_bits = 24'h000c00;
            11'd533:
                row_bits = 24'h000c00;
            11'd534:
                row_bits = 24'h000c00;
            11'd535:
                row_bits = 24'h060c00;
            11'd536:
                row_bits = 24'h060c00;
            11'd537:
                row_bits = 24'h060ff8;
            11'd538:
                row_bits = 24'h060ff8;
            11'd539:
                row_bits = 24'h060c00;
            11'd540:
                row_bits = 24'h060c00;
            11'd541:
                row_bits = 24'h060c00;
            11'd542:
                row_bits = 24'h060c00;
            11'd543:
                row_bits = 24'h060c00;
            11'd544:
                row_bits = 24'h060c00;
            11'd545:
                row_bits = 24'h060c00;
            11'd546:
                row_bits = 24'h060c00;
            11'd547:
                row_bits = 24'h060c00;
            11'd548:
                row_bits = 24'h7ffffe;
            11'd549:
                row_bits = 24'h7ffffe;
            11'd552:
                row_bits = 24'h000020;
            11'd553:
                row_bits = 24'h000ff0;
            11'd554:
                row_bits = 24'h1fffe0;
            11'd555:
                row_bits = 24'h0fd800;
            11'd556:
                row_bits = 24'h001800;
            11'd557:
                row_bits = 24'h3ffffc;
            11'd558:
                row_bits = 24'h7ffffe;
            11'd559:
                row_bits = 24'h001800;
            11'd560:
                row_bits = 24'h031998;
            11'd561:
                row_bits = 24'h3f19b8;
            11'd562:
                row_bits = 24'h3f19f0;
            11'd563:
                row_bits = 24'h0319c0;
            11'd564:
                row_bits = 24'h07398c;
            11'd565:
                row_bits = 24'h3f3dfc;
            11'd566:
                row_bits = 24'h3b7efc;
            11'd567:
                row_bits = 24'h00fb00;
            11'd568:
                row_bits = 24'h01db80;
            11'd569:
                row_bits = 24'h0399e0;
            11'd570:
                row_bits = 24'h0f1878;
            11'd571:
                row_bits = 24'h3c183e;
            11'd572:
                row_bits = 24'h30180c;
            11'd573:
                row_bits = 24'h001800;
            11'd574:
                row_bits = 24'h001000;
            11'd578:
                row_bits = 24'h001800;
            11'd579:
                row_bits = 24'h001800;
            11'd580:
                row_bits = 24'h061860;
            11'd581:
                row_bits = 24'h061860;
            11'd582:
                row_bits = 24'h0618e0;
            11'd583:
                row_bits = 24'h0e18c0;
            11'd584:
                row_bits = 24'h0e18e0;
            11'd585:
                row_bits = 24'h1f19f0;
            11'd586:
                row_bits = 24'h199998;
            11'd587:
                row_bits = 24'h39db0c;
            11'd588:
                row_bits = 24'h309f08;
            11'd589:
                row_bits = 24'h201a00;
            11'd590:
                row_bits = 24'h001800;
            11'd591:
                row_bits = 24'h0ffff0;
            11'd592:
                row_bits = 24'h1ffff8;
            11'd593:
                row_bits = 24'h001800;
            11'd594:
                row_bits = 24'h001800;
            11'd595:
                row_bits = 24'h001800;
            11'd596:
                row_bits = 24'h001800;
            11'd597:
                row_bits = 24'h7ffffe;
            11'd598:
                row_bits = 24'h200004;
            11'd600:
                row_bits = 24'h003000;
            11'd601:
                row_bits = 24'h003000;
            11'd602:
                row_bits = 24'h003000;
            11'd603:
                row_bits = 24'h003000;
            11'd604:
                row_bits = 24'h1fffe0;
            11'd605:
                row_bits = 24'h3ffff0;
            11'd606:
                row_bits = 24'h383070;
            11'd607:
                row_bits = 24'h383070;
            11'd608:
                row_bits = 24'h383070;
            11'd609:
                row_bits = 24'h3ffff0;
            11'd610:
                row_bits = 24'h3ffff0;
            11'd611:
                row_bits = 24'h383070;
            11'd612:
                row_bits = 24'h383070;
            11'd613:
                row_bits = 24'h383070;
            11'd614:
                row_bits = 24'h383070;
            11'd615:
                row_bits = 24'h3ffff0;
            11'd616:
                row_bits = 24'h383000;
            11'd617:
                row_bits = 24'h383000;
            11'd618:
                row_bits = 24'h003006;
            11'd619:
                row_bits = 24'h00300e;
            11'd620:
                row_bits = 24'h003ffe;
            11'd621:
                row_bits = 24'h001ffc;
            11'd625:
                row_bits = 24'h000840;
            11'd626:
                row_bits = 24'h0c1860;
            11'd627:
                row_bits = 24'h0c0cc0;
            11'd628:
                row_bits = 24'h0c08c0;
            11'd629:
                row_bits = 24'h0c3ff8;
            11'd630:
                row_bits = 24'h0c3ff8;
            11'd631:
                row_bits = 24'h7f8318;
            11'd632:
                row_bits = 24'h3f0318;
            11'd633:
                row_bits = 24'h0c3ff8;
            11'd634:
                row_bits = 24'h1c3ff8;
            11'd635:
                row_bits = 24'h1c3300;
            11'd636:
                row_bits = 24'h3f3300;
            11'd637:
                row_bits = 24'h3fbffc;
            11'd638:
                row_bits = 24'h7dbffc;
            11'd639:
                row_bits = 24'h6c0f0c;
            11'd640:
                row_bits = 24'h6c0f0c;
            11'd641:
                row_bits = 24'h0c1b0c;
            11'd642:
                row_bits = 24'h0c330c;
            11'd643:
                row_bits = 24'h0cf33c;
            11'd644:
                row_bits = 24'h0dc338;
            11'd645:
                row_bits = 24'h0d8300;
            11'd646:
                row_bits = 24'h0c0300;
            default:
                row_bits = 0;
        endcase
    end
endmodule
