// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：动态光晕相位和边缘深度对应的透明度查找表。
// 时钟：组合查询/透传接口，时序由调用方或子模块确定。
// 复位：本模块无复位端口或本地复位分支。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Quantized reference Gaussian halo: 64 phases, 24-pixel protected border.
module emergency_halo_profile_rom (
    input wire [5:0] phase,
    input wire [4:0] depth,
    output reg [3:0] alpha
);
    always @* begin
        case ({phase, depth})
            11'd0:
                alpha = 4'd12;
            11'd1:
                alpha = 4'd12;
            11'd2:
                alpha = 4'd11;
            11'd3:
                alpha = 4'd9;
            11'd4:
                alpha = 4'd8;
            11'd5:
                alpha = 4'd7;
            11'd6:
                alpha = 4'd5;
            11'd7:
                alpha = 4'd4;
            11'd8:
                alpha = 4'd3;
            11'd9:
                alpha = 4'd2;
            11'd10:
                alpha = 4'd2;
            11'd11:
                alpha = 4'd1;
            11'd12:
                alpha = 4'd1;
            11'd13:
                alpha = 4'd1;
            11'd32:
                alpha = 4'd13;
            11'd33:
                alpha = 4'd12;
            11'd34:
                alpha = 4'd11;
            11'd35:
                alpha = 4'd10;
            11'd36:
                alpha = 4'd9;
            11'd37:
                alpha = 4'd7;
            11'd38:
                alpha = 4'd6;
            11'd39:
                alpha = 4'd5;
            11'd40:
                alpha = 4'd4;
            11'd41:
                alpha = 4'd3;
            11'd42:
                alpha = 4'd2;
            11'd43:
                alpha = 4'd1;
            11'd44:
                alpha = 4'd1;
            11'd45:
                alpha = 4'd1;
            11'd64:
                alpha = 4'd14;
            11'd65:
                alpha = 4'd13;
            11'd66:
                alpha = 4'd12;
            11'd67:
                alpha = 4'd10;
            11'd68:
                alpha = 4'd9;
            11'd69:
                alpha = 4'd8;
            11'd70:
                alpha = 4'd6;
            11'd71:
                alpha = 4'd5;
            11'd72:
                alpha = 4'd4;
            11'd73:
                alpha = 4'd3;
            11'd74:
                alpha = 4'd2;
            11'd75:
                alpha = 4'd1;
            11'd76:
                alpha = 4'd1;
            11'd77:
                alpha = 4'd1;
            11'd96:
                alpha = 4'd14;
            11'd97:
                alpha = 4'd13;
            11'd98:
                alpha = 4'd12;
            11'd99:
                alpha = 4'd11;
            11'd100:
                alpha = 4'd9;
            11'd101:
                alpha = 4'd8;
            11'd102:
                alpha = 4'd7;
            11'd103:
                alpha = 4'd5;
            11'd104:
                alpha = 4'd4;
            11'd105:
                alpha = 4'd3;
            11'd106:
                alpha = 4'd2;
            11'd107:
                alpha = 4'd2;
            11'd108:
                alpha = 4'd1;
            11'd109:
                alpha = 4'd1;
            11'd128:
                alpha = 4'd14;
            11'd129:
                alpha = 4'd13;
            11'd130:
                alpha = 4'd12;
            11'd131:
                alpha = 4'd11;
            11'd132:
                alpha = 4'd10;
            11'd133:
                alpha = 4'd8;
            11'd134:
                alpha = 4'd7;
            11'd135:
                alpha = 4'd6;
            11'd136:
                alpha = 4'd4;
            11'd137:
                alpha = 4'd3;
            11'd138:
                alpha = 4'd2;
            11'd139:
                alpha = 4'd2;
            11'd140:
                alpha = 4'd1;
            11'd141:
                alpha = 4'd1;
            11'd142:
                alpha = 4'd1;
            11'd160:
                alpha = 4'd14;
            11'd161:
                alpha = 4'd13;
            11'd162:
                alpha = 4'd12;
            11'd163:
                alpha = 4'd11;
            11'd164:
                alpha = 4'd10;
            11'd165:
                alpha = 4'd9;
            11'd166:
                alpha = 4'd7;
            11'd167:
                alpha = 4'd6;
            11'd168:
                alpha = 4'd5;
            11'd169:
                alpha = 4'd4;
            11'd170:
                alpha = 4'd3;
            11'd171:
                alpha = 4'd2;
            11'd172:
                alpha = 4'd1;
            11'd173:
                alpha = 4'd1;
            11'd174:
                alpha = 4'd1;
            11'd192:
                alpha = 4'd13;
            11'd193:
                alpha = 4'd13;
            11'd194:
                alpha = 4'd12;
            11'd195:
                alpha = 4'd11;
            11'd196:
                alpha = 4'd10;
            11'd197:
                alpha = 4'd9;
            11'd198:
                alpha = 4'd7;
            11'd199:
                alpha = 4'd6;
            11'd200:
                alpha = 4'd5;
            11'd201:
                alpha = 4'd4;
            11'd202:
                alpha = 4'd3;
            11'd203:
                alpha = 4'd2;
            11'd204:
                alpha = 4'd2;
            11'd205:
                alpha = 4'd1;
            11'd206:
                alpha = 4'd1;
            11'd224:
                alpha = 4'd12;
            11'd225:
                alpha = 4'd12;
            11'd226:
                alpha = 4'd11;
            11'd227:
                alpha = 4'd11;
            11'd228:
                alpha = 4'd10;
            11'd229:
                alpha = 4'd9;
            11'd230:
                alpha = 4'd7;
            11'd231:
                alpha = 4'd6;
            11'd232:
                alpha = 4'd5;
            11'd233:
                alpha = 4'd4;
            11'd234:
                alpha = 4'd3;
            11'd235:
                alpha = 4'd2;
            11'd236:
                alpha = 4'd2;
            11'd237:
                alpha = 4'd1;
            11'd238:
                alpha = 4'd1;
            11'd256:
                alpha = 4'd11;
            11'd257:
                alpha = 4'd11;
            11'd258:
                alpha = 4'd11;
            11'd259:
                alpha = 4'd10;
            11'd260:
                alpha = 4'd9;
            11'd261:
                alpha = 4'd8;
            11'd262:
                alpha = 4'd7;
            11'd263:
                alpha = 4'd6;
            11'd264:
                alpha = 4'd5;
            11'd265:
                alpha = 4'd4;
            11'd266:
                alpha = 4'd3;
            11'd267:
                alpha = 4'd3;
            11'd268:
                alpha = 4'd2;
            11'd269:
                alpha = 4'd1;
            11'd270:
                alpha = 4'd1;
            11'd271:
                alpha = 4'd1;
            11'd288:
                alpha = 4'd9;
            11'd289:
                alpha = 4'd10;
            11'd290:
                alpha = 4'd9;
            11'd291:
                alpha = 4'd9;
            11'd292:
                alpha = 4'd8;
            11'd293:
                alpha = 4'd8;
            11'd294:
                alpha = 4'd7;
            11'd295:
                alpha = 4'd6;
            11'd296:
                alpha = 4'd5;
            11'd297:
                alpha = 4'd4;
            11'd298:
                alpha = 4'd3;
            11'd299:
                alpha = 4'd3;
            11'd300:
                alpha = 4'd2;
            11'd301:
                alpha = 4'd1;
            11'd302:
                alpha = 4'd1;
            11'd303:
                alpha = 4'd1;
            11'd320:
                alpha = 4'd8;
            11'd321:
                alpha = 4'd8;
            11'd322:
                alpha = 4'd8;
            11'd323:
                alpha = 4'd8;
            11'd324:
                alpha = 4'd8;
            11'd325:
                alpha = 4'd7;
            11'd326:
                alpha = 4'd6;
            11'd327:
                alpha = 4'd6;
            11'd328:
                alpha = 4'd5;
            11'd329:
                alpha = 4'd4;
            11'd330:
                alpha = 4'd3;
            11'd331:
                alpha = 4'd3;
            11'd332:
                alpha = 4'd2;
            11'd333:
                alpha = 4'd2;
            11'd334:
                alpha = 4'd1;
            11'd335:
                alpha = 4'd1;
            11'd352:
                alpha = 4'd6;
            11'd353:
                alpha = 4'd6;
            11'd354:
                alpha = 4'd7;
            11'd355:
                alpha = 4'd7;
            11'd356:
                alpha = 4'd6;
            11'd357:
                alpha = 4'd6;
            11'd358:
                alpha = 4'd6;
            11'd359:
                alpha = 4'd5;
            11'd360:
                alpha = 4'd4;
            11'd361:
                alpha = 4'd4;
            11'd362:
                alpha = 4'd3;
            11'd363:
                alpha = 4'd3;
            11'd364:
                alpha = 4'd2;
            11'd365:
                alpha = 4'd2;
            11'd366:
                alpha = 4'd1;
            11'd367:
                alpha = 4'd1;
            11'd384:
                alpha = 4'd5;
            11'd385:
                alpha = 4'd5;
            11'd386:
                alpha = 4'd5;
            11'd387:
                alpha = 4'd5;
            11'd388:
                alpha = 4'd5;
            11'd389:
                alpha = 4'd5;
            11'd390:
                alpha = 4'd5;
            11'd391:
                alpha = 4'd4;
            11'd392:
                alpha = 4'd4;
            11'd393:
                alpha = 4'd3;
            11'd394:
                alpha = 4'd3;
            11'd395:
                alpha = 4'd2;
            11'd396:
                alpha = 4'd2;
            11'd397:
                alpha = 4'd2;
            11'd398:
                alpha = 4'd1;
            11'd399:
                alpha = 4'd1;
            11'd400:
                alpha = 4'd1;
            11'd416:
                alpha = 4'd3;
            11'd417:
                alpha = 4'd4;
            11'd418:
                alpha = 4'd4;
            11'd419:
                alpha = 4'd4;
            11'd420:
                alpha = 4'd4;
            11'd421:
                alpha = 4'd4;
            11'd422:
                alpha = 4'd4;
            11'd423:
                alpha = 4'd3;
            11'd424:
                alpha = 4'd3;
            11'd425:
                alpha = 4'd3;
            11'd426:
                alpha = 4'd2;
            11'd427:
                alpha = 4'd2;
            11'd428:
                alpha = 4'd2;
            11'd429:
                alpha = 4'd1;
            11'd430:
                alpha = 4'd1;
            11'd431:
                alpha = 4'd1;
            11'd448:
                alpha = 4'd2;
            11'd449:
                alpha = 4'd2;
            11'd450:
                alpha = 4'd3;
            11'd451:
                alpha = 4'd3;
            11'd452:
                alpha = 4'd3;
            11'd453:
                alpha = 4'd3;
            11'd454:
                alpha = 4'd3;
            11'd455:
                alpha = 4'd3;
            11'd456:
                alpha = 4'd2;
            11'd457:
                alpha = 4'd2;
            11'd458:
                alpha = 4'd2;
            11'd459:
                alpha = 4'd2;
            11'd460:
                alpha = 4'd1;
            11'd461:
                alpha = 4'd1;
            11'd462:
                alpha = 4'd1;
            11'd463:
                alpha = 4'd1;
            11'd480:
                alpha = 4'd1;
            11'd481:
                alpha = 4'd2;
            11'd482:
                alpha = 4'd2;
            11'd483:
                alpha = 4'd2;
            11'd484:
                alpha = 4'd2;
            11'd485:
                alpha = 4'd2;
            11'd486:
                alpha = 4'd2;
            11'd487:
                alpha = 4'd2;
            11'd488:
                alpha = 4'd2;
            11'd489:
                alpha = 4'd2;
            11'd490:
                alpha = 4'd2;
            11'd491:
                alpha = 4'd1;
            11'd492:
                alpha = 4'd1;
            11'd493:
                alpha = 4'd1;
            11'd494:
                alpha = 4'd1;
            11'd495:
                alpha = 4'd1;
            11'd512:
                alpha = 4'd1;
            11'd513:
                alpha = 4'd1;
            11'd514:
                alpha = 4'd1;
            11'd515:
                alpha = 4'd1;
            11'd516:
                alpha = 4'd1;
            11'd517:
                alpha = 4'd1;
            11'd518:
                alpha = 4'd1;
            11'd519:
                alpha = 4'd1;
            11'd520:
                alpha = 4'd1;
            11'd521:
                alpha = 4'd1;
            11'd522:
                alpha = 4'd1;
            11'd523:
                alpha = 4'd1;
            11'd524:
                alpha = 4'd1;
            11'd525:
                alpha = 4'd1;
            11'd526:
                alpha = 4'd1;
            11'd544:
                alpha = 4'd1;
            11'd545:
                alpha = 4'd1;
            11'd546:
                alpha = 4'd1;
            11'd547:
                alpha = 4'd1;
            11'd548:
                alpha = 4'd1;
            11'd549:
                alpha = 4'd1;
            11'd550:
                alpha = 4'd1;
            11'd551:
                alpha = 4'd1;
            11'd552:
                alpha = 4'd1;
            11'd553:
                alpha = 4'd1;
            11'd554:
                alpha = 4'd1;
            11'd555:
                alpha = 4'd1;
            11'd556:
                alpha = 4'd1;
            11'd557:
                alpha = 4'd1;
            11'd578:
                alpha = 4'd1;
            11'd579:
                alpha = 4'd1;
            11'd580:
                alpha = 4'd1;
            11'd581:
                alpha = 4'd1;
            11'd582:
                alpha = 4'd1;
            11'd583:
                alpha = 4'd1;
            11'd584:
                alpha = 4'd1;
            11'd585:
                alpha = 4'd1;
            11'd586:
                alpha = 4'd1;
            11'd587:
                alpha = 4'd1;
            11'd588:
                alpha = 4'd1;
            11'd589:
                alpha = 4'd1;
            11'd611:
                alpha = 4'd1;
            11'd612:
                alpha = 4'd1;
            11'd613:
                alpha = 4'd1;
            11'd614:
                alpha = 4'd1;
            11'd615:
                alpha = 4'd1;
            11'd616:
                alpha = 4'd1;
            11'd617:
                alpha = 4'd1;
            11'd618:
                alpha = 4'd1;
            11'd619:
                alpha = 4'd1;
            11'd620:
                alpha = 4'd1;
            11'd621:
                alpha = 4'd1;
            11'd644:
                alpha = 4'd1;
            11'd645:
                alpha = 4'd1;
            11'd646:
                alpha = 4'd1;
            11'd647:
                alpha = 4'd1;
            11'd648:
                alpha = 4'd1;
            11'd649:
                alpha = 4'd1;
            11'd650:
                alpha = 4'd1;
            11'd651:
                alpha = 4'd1;
            11'd652:
                alpha = 4'd1;
            11'd653:
                alpha = 4'd1;
            11'd654:
                alpha = 4'd1;
            11'd675:
                alpha = 4'd1;
            11'd676:
                alpha = 4'd1;
            11'd677:
                alpha = 4'd1;
            11'd678:
                alpha = 4'd1;
            11'd679:
                alpha = 4'd1;
            11'd680:
                alpha = 4'd1;
            11'd681:
                alpha = 4'd1;
            11'd682:
                alpha = 4'd1;
            11'd683:
                alpha = 4'd1;
            11'd684:
                alpha = 4'd1;
            11'd685:
                alpha = 4'd1;
            11'd686:
                alpha = 4'd1;
            11'd687:
                alpha = 4'd1;
            11'd705:
                alpha = 4'd1;
            11'd706:
                alpha = 4'd1;
            11'd707:
                alpha = 4'd1;
            11'd708:
                alpha = 4'd1;
            11'd709:
                alpha = 4'd1;
            11'd710:
                alpha = 4'd1;
            11'd711:
                alpha = 4'd1;
            11'd712:
                alpha = 4'd1;
            11'd713:
                alpha = 4'd1;
            11'd714:
                alpha = 4'd1;
            11'd715:
                alpha = 4'd1;
            11'd716:
                alpha = 4'd1;
            11'd717:
                alpha = 4'd1;
            11'd718:
                alpha = 4'd1;
            11'd719:
                alpha = 4'd1;
            11'd720:
                alpha = 4'd1;
            11'd721:
                alpha = 4'd1;
            11'd736:
                alpha = 4'd1;
            11'd737:
                alpha = 4'd1;
            11'd738:
                alpha = 4'd1;
            11'd739:
                alpha = 4'd1;
            11'd740:
                alpha = 4'd1;
            11'd741:
                alpha = 4'd1;
            11'd742:
                alpha = 4'd1;
            11'd743:
                alpha = 4'd2;
            11'd744:
                alpha = 4'd2;
            11'd745:
                alpha = 4'd2;
            11'd746:
                alpha = 4'd2;
            11'd747:
                alpha = 4'd2;
            11'd748:
                alpha = 4'd2;
            11'd749:
                alpha = 4'd2;
            11'd750:
                alpha = 4'd2;
            11'd751:
                alpha = 4'd1;
            11'd752:
                alpha = 4'd1;
            11'd753:
                alpha = 4'd1;
            11'd754:
                alpha = 4'd1;
            11'd768:
                alpha = 4'd1;
            11'd769:
                alpha = 4'd1;
            11'd770:
                alpha = 4'd1;
            11'd771:
                alpha = 4'd1;
            11'd772:
                alpha = 4'd2;
            11'd773:
                alpha = 4'd2;
            11'd774:
                alpha = 4'd2;
            11'd775:
                alpha = 4'd2;
            11'd776:
                alpha = 4'd2;
            11'd777:
                alpha = 4'd3;
            11'd778:
                alpha = 4'd3;
            11'd779:
                alpha = 4'd3;
            11'd780:
                alpha = 4'd3;
            11'd781:
                alpha = 4'd3;
            11'd782:
                alpha = 4'd2;
            11'd783:
                alpha = 4'd2;
            11'd784:
                alpha = 4'd2;
            11'd785:
                alpha = 4'd1;
            11'd786:
                alpha = 4'd1;
            11'd787:
                alpha = 4'd1;
            11'd800:
                alpha = 4'd1;
            11'd801:
                alpha = 4'd1;
            11'd802:
                alpha = 4'd1;
            11'd803:
                alpha = 4'd2;
            11'd804:
                alpha = 4'd2;
            11'd805:
                alpha = 4'd2;
            11'd806:
                alpha = 4'd3;
            11'd807:
                alpha = 4'd3;
            11'd808:
                alpha = 4'd3;
            11'd809:
                alpha = 4'd3;
            11'd810:
                alpha = 4'd4;
            11'd811:
                alpha = 4'd4;
            11'd812:
                alpha = 4'd4;
            11'd813:
                alpha = 4'd4;
            11'd814:
                alpha = 4'd3;
            11'd815:
                alpha = 4'd3;
            11'd816:
                alpha = 4'd2;
            11'd817:
                alpha = 4'd2;
            11'd818:
                alpha = 4'd1;
            11'd819:
                alpha = 4'd1;
            11'd820:
                alpha = 4'd1;
            11'd832:
                alpha = 4'd1;
            11'd833:
                alpha = 4'd1;
            11'd834:
                alpha = 4'd2;
            11'd835:
                alpha = 4'd2;
            11'd836:
                alpha = 4'd3;
            11'd837:
                alpha = 4'd3;
            11'd838:
                alpha = 4'd3;
            11'd839:
                alpha = 4'd4;
            11'd840:
                alpha = 4'd4;
            11'd841:
                alpha = 4'd4;
            11'd842:
                alpha = 4'd5;
            11'd843:
                alpha = 4'd5;
            11'd844:
                alpha = 4'd5;
            11'd845:
                alpha = 4'd5;
            11'd846:
                alpha = 4'd5;
            11'd847:
                alpha = 4'd4;
            11'd848:
                alpha = 4'd3;
            11'd849:
                alpha = 4'd3;
            11'd850:
                alpha = 4'd2;
            11'd851:
                alpha = 4'd1;
            11'd852:
                alpha = 4'd1;
            11'd864:
                alpha = 4'd1;
            11'd865:
                alpha = 4'd2;
            11'd866:
                alpha = 4'd2;
            11'd867:
                alpha = 4'd3;
            11'd868:
                alpha = 4'd3;
            11'd869:
                alpha = 4'd4;
            11'd870:
                alpha = 4'd4;
            11'd871:
                alpha = 4'd5;
            11'd872:
                alpha = 4'd5;
            11'd873:
                alpha = 4'd6;
            11'd874:
                alpha = 4'd6;
            11'd875:
                alpha = 4'd6;
            11'd876:
                alpha = 4'd6;
            11'd877:
                alpha = 4'd6;
            11'd878:
                alpha = 4'd6;
            11'd879:
                alpha = 4'd5;
            11'd880:
                alpha = 4'd4;
            11'd881:
                alpha = 4'd3;
            11'd882:
                alpha = 4'd3;
            11'd883:
                alpha = 4'd2;
            11'd884:
                alpha = 4'd1;
            11'd885:
                alpha = 4'd1;
            11'd896:
                alpha = 4'd2;
            11'd897:
                alpha = 4'd2;
            11'd898:
                alpha = 4'd2;
            11'd899:
                alpha = 4'd3;
            11'd900:
                alpha = 4'd4;
            11'd901:
                alpha = 4'd4;
            11'd902:
                alpha = 4'd5;
            11'd903:
                alpha = 4'd5;
            11'd904:
                alpha = 4'd6;
            11'd905:
                alpha = 4'd7;
            11'd906:
                alpha = 4'd7;
            11'd907:
                alpha = 4'd8;
            11'd908:
                alpha = 4'd8;
            11'd909:
                alpha = 4'd8;
            11'd910:
                alpha = 4'd7;
            11'd911:
                alpha = 4'd7;
            11'd912:
                alpha = 4'd6;
            11'd913:
                alpha = 4'd4;
            11'd914:
                alpha = 4'd3;
            11'd915:
                alpha = 4'd2;
            11'd916:
                alpha = 4'd1;
            11'd917:
                alpha = 4'd1;
            11'd928:
                alpha = 4'd2;
            11'd929:
                alpha = 4'd2;
            11'd930:
                alpha = 4'd3;
            11'd931:
                alpha = 4'd3;
            11'd932:
                alpha = 4'd4;
            11'd933:
                alpha = 4'd5;
            11'd934:
                alpha = 4'd6;
            11'd935:
                alpha = 4'd6;
            11'd936:
                alpha = 4'd7;
            11'd937:
                alpha = 4'd8;
            11'd938:
                alpha = 4'd8;
            11'd939:
                alpha = 4'd9;
            11'd940:
                alpha = 4'd9;
            11'd941:
                alpha = 4'd9;
            11'd942:
                alpha = 4'd9;
            11'd943:
                alpha = 4'd8;
            11'd944:
                alpha = 4'd7;
            11'd945:
                alpha = 4'd5;
            11'd946:
                alpha = 4'd4;
            11'd947:
                alpha = 4'd3;
            11'd948:
                alpha = 4'd2;
            11'd949:
                alpha = 4'd1;
            11'd960:
                alpha = 4'd2;
            11'd961:
                alpha = 4'd2;
            11'd962:
                alpha = 4'd3;
            11'd963:
                alpha = 4'd4;
            11'd964:
                alpha = 4'd5;
            11'd965:
                alpha = 4'd5;
            11'd966:
                alpha = 4'd6;
            11'd967:
                alpha = 4'd7;
            11'd968:
                alpha = 4'd8;
            11'd969:
                alpha = 4'd9;
            11'd970:
                alpha = 4'd9;
            11'd971:
                alpha = 4'd10;
            11'd972:
                alpha = 4'd10;
            11'd973:
                alpha = 4'd11;
            11'd974:
                alpha = 4'd10;
            11'd975:
                alpha = 4'd9;
            11'd976:
                alpha = 4'd8;
            11'd977:
                alpha = 4'd6;
            11'd978:
                alpha = 4'd5;
            11'd979:
                alpha = 4'd3;
            11'd980:
                alpha = 4'd2;
            11'd981:
                alpha = 4'd1;
            11'd992:
                alpha = 4'd2;
            11'd993:
                alpha = 4'd3;
            11'd994:
                alpha = 4'd3;
            11'd995:
                alpha = 4'd4;
            11'd996:
                alpha = 4'd5;
            11'd997:
                alpha = 4'd6;
            11'd998:
                alpha = 4'd7;
            11'd999:
                alpha = 4'd8;
            11'd1000:
                alpha = 4'd9;
            11'd1001:
                alpha = 4'd10;
            11'd1002:
                alpha = 4'd10;
            11'd1003:
                alpha = 4'd11;
            11'd1004:
                alpha = 4'd12;
            11'd1005:
                alpha = 4'd12;
            11'd1006:
                alpha = 4'd11;
            11'd1007:
                alpha = 4'd10;
            11'd1008:
                alpha = 4'd9;
            11'd1009:
                alpha = 4'd7;
            11'd1010:
                alpha = 4'd5;
            11'd1011:
                alpha = 4'd4;
            11'd1012:
                alpha = 4'd2;
            11'd1013:
                alpha = 4'd1;
            11'd1014:
                alpha = 4'd1;
            11'd1024:
                alpha = 4'd2;
            11'd1025:
                alpha = 4'd3;
            11'd1026:
                alpha = 4'd4;
            11'd1027:
                alpha = 4'd4;
            11'd1028:
                alpha = 4'd5;
            11'd1029:
                alpha = 4'd6;
            11'd1030:
                alpha = 4'd7;
            11'd1031:
                alpha = 4'd8;
            11'd1032:
                alpha = 4'd10;
            11'd1033:
                alpha = 4'd11;
            11'd1034:
                alpha = 4'd11;
            11'd1035:
                alpha = 4'd12;
            11'd1036:
                alpha = 4'd13;
            11'd1037:
                alpha = 4'd13;
            11'd1038:
                alpha = 4'd12;
            11'd1039:
                alpha = 4'd11;
            11'd1040:
                alpha = 4'd9;
            11'd1041:
                alpha = 4'd8;
            11'd1042:
                alpha = 4'd6;
            11'd1043:
                alpha = 4'd4;
            11'd1044:
                alpha = 4'd2;
            11'd1045:
                alpha = 4'd1;
            11'd1046:
                alpha = 4'd1;
            11'd1056:
                alpha = 4'd2;
            11'd1057:
                alpha = 4'd3;
            11'd1058:
                alpha = 4'd4;
            11'd1059:
                alpha = 4'd5;
            11'd1060:
                alpha = 4'd6;
            11'd1061:
                alpha = 4'd7;
            11'd1062:
                alpha = 4'd8;
            11'd1063:
                alpha = 4'd9;
            11'd1064:
                alpha = 4'd10;
            11'd1065:
                alpha = 4'd11;
            11'd1066:
                alpha = 4'd12;
            11'd1067:
                alpha = 4'd13;
            11'd1068:
                alpha = 4'd13;
            11'd1069:
                alpha = 4'd14;
            11'd1070:
                alpha = 4'd13;
            11'd1071:
                alpha = 4'd12;
            11'd1072:
                alpha = 4'd10;
            11'd1073:
                alpha = 4'd8;
            11'd1074:
                alpha = 4'd6;
            11'd1075:
                alpha = 4'd4;
            11'd1076:
                alpha = 4'd3;
            11'd1077:
                alpha = 4'd1;
            11'd1078:
                alpha = 4'd1;
            11'd1088:
                alpha = 4'd3;
            11'd1089:
                alpha = 4'd3;
            11'd1090:
                alpha = 4'd4;
            11'd1091:
                alpha = 4'd5;
            11'd1092:
                alpha = 4'd6;
            11'd1093:
                alpha = 4'd7;
            11'd1094:
                alpha = 4'd8;
            11'd1095:
                alpha = 4'd10;
            11'd1096:
                alpha = 4'd11;
            11'd1097:
                alpha = 4'd12;
            11'd1098:
                alpha = 4'd13;
            11'd1099:
                alpha = 4'd13;
            11'd1100:
                alpha = 4'd14;
            11'd1101:
                alpha = 4'd14;
            11'd1102:
                alpha = 4'd13;
            11'd1103:
                alpha = 4'd12;
            11'd1104:
                alpha = 4'd10;
            11'd1105:
                alpha = 4'd8;
            11'd1106:
                alpha = 4'd6;
            11'd1107:
                alpha = 4'd4;
            11'd1108:
                alpha = 4'd3;
            11'd1109:
                alpha = 4'd1;
            11'd1110:
                alpha = 4'd1;
            11'd1120:
                alpha = 4'd3;
            11'd1121:
                alpha = 4'd3;
            11'd1122:
                alpha = 4'd4;
            11'd1123:
                alpha = 4'd5;
            11'd1124:
                alpha = 4'd6;
            11'd1125:
                alpha = 4'd7;
            11'd1126:
                alpha = 4'd9;
            11'd1127:
                alpha = 4'd10;
            11'd1128:
                alpha = 4'd11;
            11'd1129:
                alpha = 4'd12;
            11'd1130:
                alpha = 4'd13;
            11'd1131:
                alpha = 4'd14;
            11'd1132:
                alpha = 4'd14;
            11'd1133:
                alpha = 4'd14;
            11'd1134:
                alpha = 4'd14;
            11'd1135:
                alpha = 4'd12;
            11'd1136:
                alpha = 4'd10;
            11'd1137:
                alpha = 4'd8;
            11'd1138:
                alpha = 4'd6;
            11'd1139:
                alpha = 4'd4;
            11'd1140:
                alpha = 4'd3;
            11'd1141:
                alpha = 4'd1;
            11'd1142:
                alpha = 4'd1;
            11'd1152:
                alpha = 4'd3;
            11'd1153:
                alpha = 4'd4;
            11'd1154:
                alpha = 4'd4;
            11'd1155:
                alpha = 4'd5;
            11'd1156:
                alpha = 4'd7;
            11'd1157:
                alpha = 4'd8;
            11'd1158:
                alpha = 4'd9;
            11'd1159:
                alpha = 4'd10;
            11'd1160:
                alpha = 4'd11;
            11'd1161:
                alpha = 4'd12;
            11'd1162:
                alpha = 4'd13;
            11'd1163:
                alpha = 4'd14;
            11'd1164:
                alpha = 4'd14;
            11'd1165:
                alpha = 4'd14;
            11'd1166:
                alpha = 4'd13;
            11'd1167:
                alpha = 4'd12;
            11'd1168:
                alpha = 4'd10;
            11'd1169:
                alpha = 4'd8;
            11'd1170:
                alpha = 4'd6;
            11'd1171:
                alpha = 4'd4;
            11'd1172:
                alpha = 4'd3;
            11'd1173:
                alpha = 4'd1;
            11'd1174:
                alpha = 4'd1;
            11'd1184:
                alpha = 4'd3;
            11'd1185:
                alpha = 4'd4;
            11'd1186:
                alpha = 4'd5;
            11'd1187:
                alpha = 4'd6;
            11'd1188:
                alpha = 4'd7;
            11'd1189:
                alpha = 4'd8;
            11'd1190:
                alpha = 4'd9;
            11'd1191:
                alpha = 4'd10;
            11'd1192:
                alpha = 4'd11;
            11'd1193:
                alpha = 4'd12;
            11'd1194:
                alpha = 4'd13;
            11'd1195:
                alpha = 4'd13;
            11'd1196:
                alpha = 4'd14;
            11'd1197:
                alpha = 4'd14;
            11'd1198:
                alpha = 4'd13;
            11'd1199:
                alpha = 4'd11;
            11'd1200:
                alpha = 4'd10;
            11'd1201:
                alpha = 4'd8;
            11'd1202:
                alpha = 4'd6;
            11'd1203:
                alpha = 4'd4;
            11'd1204:
                alpha = 4'd2;
            11'd1205:
                alpha = 4'd1;
            11'd1206:
                alpha = 4'd1;
            11'd1216:
                alpha = 4'd3;
            11'd1217:
                alpha = 4'd4;
            11'd1218:
                alpha = 4'd5;
            11'd1219:
                alpha = 4'd6;
            11'd1220:
                alpha = 4'd7;
            11'd1221:
                alpha = 4'd8;
            11'd1222:
                alpha = 4'd9;
            11'd1223:
                alpha = 4'd10;
            11'd1224:
                alpha = 4'd11;
            11'd1225:
                alpha = 4'd12;
            11'd1226:
                alpha = 4'd12;
            11'd1227:
                alpha = 4'd13;
            11'd1228:
                alpha = 4'd13;
            11'd1229:
                alpha = 4'd13;
            11'd1230:
                alpha = 4'd12;
            11'd1231:
                alpha = 4'd11;
            11'd1232:
                alpha = 4'd9;
            11'd1233:
                alpha = 4'd7;
            11'd1234:
                alpha = 4'd5;
            11'd1235:
                alpha = 4'd3;
            11'd1236:
                alpha = 4'd2;
            11'd1237:
                alpha = 4'd1;
            11'd1248:
                alpha = 4'd3;
            11'd1249:
                alpha = 4'd4;
            11'd1250:
                alpha = 4'd5;
            11'd1251:
                alpha = 4'd6;
            11'd1252:
                alpha = 4'd7;
            11'd1253:
                alpha = 4'd8;
            11'd1254:
                alpha = 4'd9;
            11'd1255:
                alpha = 4'd9;
            11'd1256:
                alpha = 4'd10;
            11'd1257:
                alpha = 4'd11;
            11'd1258:
                alpha = 4'd12;
            11'd1259:
                alpha = 4'd12;
            11'd1260:
                alpha = 4'd12;
            11'd1261:
                alpha = 4'd12;
            11'd1262:
                alpha = 4'd11;
            11'd1263:
                alpha = 4'd10;
            11'd1264:
                alpha = 4'd8;
            11'd1265:
                alpha = 4'd6;
            11'd1266:
                alpha = 4'd4;
            11'd1267:
                alpha = 4'd3;
            11'd1268:
                alpha = 4'd2;
            11'd1269:
                alpha = 4'd1;
            11'd1280:
                alpha = 4'd3;
            11'd1281:
                alpha = 4'd4;
            11'd1282:
                alpha = 4'd5;
            11'd1283:
                alpha = 4'd5;
            11'd1284:
                alpha = 4'd6;
            11'd1285:
                alpha = 4'd7;
            11'd1286:
                alpha = 4'd8;
            11'd1287:
                alpha = 4'd9;
            11'd1288:
                alpha = 4'd10;
            11'd1289:
                alpha = 4'd10;
            11'd1290:
                alpha = 4'd11;
            11'd1291:
                alpha = 4'd11;
            11'd1292:
                alpha = 4'd11;
            11'd1293:
                alpha = 4'd11;
            11'd1294:
                alpha = 4'd10;
            11'd1295:
                alpha = 4'd8;
            11'd1296:
                alpha = 4'd7;
            11'd1297:
                alpha = 4'd5;
            11'd1298:
                alpha = 4'd4;
            11'd1299:
                alpha = 4'd2;
            11'd1300:
                alpha = 4'd1;
            11'd1301:
                alpha = 4'd1;
            11'd1312:
                alpha = 4'd3;
            11'd1313:
                alpha = 4'd4;
            11'd1314:
                alpha = 4'd4;
            11'd1315:
                alpha = 4'd5;
            11'd1316:
                alpha = 4'd6;
            11'd1317:
                alpha = 4'd7;
            11'd1318:
                alpha = 4'd7;
            11'd1319:
                alpha = 4'd8;
            11'd1320:
                alpha = 4'd9;
            11'd1321:
                alpha = 4'd9;
            11'd1322:
                alpha = 4'd9;
            11'd1323:
                alpha = 4'd10;
            11'd1324:
                alpha = 4'd9;
            11'd1325:
                alpha = 4'd9;
            11'd1326:
                alpha = 4'd8;
            11'd1327:
                alpha = 4'd7;
            11'd1328:
                alpha = 4'd6;
            11'd1329:
                alpha = 4'd4;
            11'd1330:
                alpha = 4'd3;
            11'd1331:
                alpha = 4'd2;
            11'd1332:
                alpha = 4'd1;
            11'd1333:
                alpha = 4'd1;
            11'd1344:
                alpha = 4'd3;
            11'd1345:
                alpha = 4'd3;
            11'd1346:
                alpha = 4'd4;
            11'd1347:
                alpha = 4'd5;
            11'd1348:
                alpha = 4'd5;
            11'd1349:
                alpha = 4'd6;
            11'd1350:
                alpha = 4'd7;
            11'd1351:
                alpha = 4'd7;
            11'd1352:
                alpha = 4'd8;
            11'd1353:
                alpha = 4'd8;
            11'd1354:
                alpha = 4'd8;
            11'd1355:
                alpha = 4'd8;
            11'd1356:
                alpha = 4'd8;
            11'd1357:
                alpha = 4'd7;
            11'd1358:
                alpha = 4'd7;
            11'd1359:
                alpha = 4'd6;
            11'd1360:
                alpha = 4'd4;
            11'd1361:
                alpha = 4'd3;
            11'd1362:
                alpha = 4'd2;
            11'd1363:
                alpha = 4'd1;
            11'd1364:
                alpha = 4'd1;
            11'd1376:
                alpha = 4'd3;
            11'd1377:
                alpha = 4'd3;
            11'd1378:
                alpha = 4'd4;
            11'd1379:
                alpha = 4'd4;
            11'd1380:
                alpha = 4'd5;
            11'd1381:
                alpha = 4'd5;
            11'd1382:
                alpha = 4'd6;
            11'd1383:
                alpha = 4'd6;
            11'd1384:
                alpha = 4'd6;
            11'd1385:
                alpha = 4'd7;
            11'd1386:
                alpha = 4'd7;
            11'd1387:
                alpha = 4'd7;
            11'd1388:
                alpha = 4'd6;
            11'd1389:
                alpha = 4'd6;
            11'd1390:
                alpha = 4'd5;
            11'd1391:
                alpha = 4'd4;
            11'd1392:
                alpha = 4'd3;
            11'd1393:
                alpha = 4'd2;
            11'd1394:
                alpha = 4'd2;
            11'd1395:
                alpha = 4'd1;
            11'd1396:
                alpha = 4'd1;
            11'd1408:
                alpha = 4'd2;
            11'd1409:
                alpha = 4'd3;
            11'd1410:
                alpha = 4'd3;
            11'd1411:
                alpha = 4'd4;
            11'd1412:
                alpha = 4'd4;
            11'd1413:
                alpha = 4'd4;
            11'd1414:
                alpha = 4'd5;
            11'd1415:
                alpha = 4'd5;
            11'd1416:
                alpha = 4'd5;
            11'd1417:
                alpha = 4'd5;
            11'd1418:
                alpha = 4'd5;
            11'd1419:
                alpha = 4'd5;
            11'd1420:
                alpha = 4'd5;
            11'd1421:
                alpha = 4'd4;
            11'd1422:
                alpha = 4'd4;
            11'd1423:
                alpha = 4'd3;
            11'd1424:
                alpha = 4'd2;
            11'd1425:
                alpha = 4'd2;
            11'd1426:
                alpha = 4'd1;
            11'd1427:
                alpha = 4'd1;
            11'd1440:
                alpha = 4'd2;
            11'd1441:
                alpha = 4'd2;
            11'd1442:
                alpha = 4'd3;
            11'd1443:
                alpha = 4'd3;
            11'd1444:
                alpha = 4'd3;
            11'd1445:
                alpha = 4'd4;
            11'd1446:
                alpha = 4'd4;
            11'd1447:
                alpha = 4'd4;
            11'd1448:
                alpha = 4'd4;
            11'd1449:
                alpha = 4'd4;
            11'd1450:
                alpha = 4'd4;
            11'd1451:
                alpha = 4'd4;
            11'd1452:
                alpha = 4'd3;
            11'd1453:
                alpha = 4'd3;
            11'd1454:
                alpha = 4'd3;
            11'd1455:
                alpha = 4'd2;
            11'd1456:
                alpha = 4'd2;
            11'd1457:
                alpha = 4'd1;
            11'd1458:
                alpha = 4'd1;
            11'd1472:
                alpha = 4'd2;
            11'd1473:
                alpha = 4'd2;
            11'd1474:
                alpha = 4'd2;
            11'd1475:
                alpha = 4'd2;
            11'd1476:
                alpha = 4'd3;
            11'd1477:
                alpha = 4'd3;
            11'd1478:
                alpha = 4'd3;
            11'd1479:
                alpha = 4'd3;
            11'd1480:
                alpha = 4'd3;
            11'd1481:
                alpha = 4'd3;
            11'd1482:
                alpha = 4'd3;
            11'd1483:
                alpha = 4'd3;
            11'd1484:
                alpha = 4'd2;
            11'd1485:
                alpha = 4'd2;
            11'd1486:
                alpha = 4'd2;
            11'd1487:
                alpha = 4'd1;
            11'd1488:
                alpha = 4'd1;
            11'd1489:
                alpha = 4'd1;
            11'd1504:
                alpha = 4'd1;
            11'd1505:
                alpha = 4'd1;
            11'd1506:
                alpha = 4'd2;
            11'd1507:
                alpha = 4'd2;
            11'd1508:
                alpha = 4'd2;
            11'd1509:
                alpha = 4'd2;
            11'd1510:
                alpha = 4'd2;
            11'd1511:
                alpha = 4'd2;
            11'd1512:
                alpha = 4'd2;
            11'd1513:
                alpha = 4'd2;
            11'd1514:
                alpha = 4'd2;
            11'd1515:
                alpha = 4'd2;
            11'd1516:
                alpha = 4'd1;
            11'd1517:
                alpha = 4'd1;
            11'd1518:
                alpha = 4'd1;
            11'd1519:
                alpha = 4'd1;
            11'd1520:
                alpha = 4'd1;
            11'd1536:
                alpha = 4'd1;
            11'd1537:
                alpha = 4'd1;
            11'd1538:
                alpha = 4'd1;
            11'd1539:
                alpha = 4'd1;
            11'd1540:
                alpha = 4'd1;
            11'd1541:
                alpha = 4'd1;
            11'd1542:
                alpha = 4'd1;
            11'd1543:
                alpha = 4'd1;
            11'd1544:
                alpha = 4'd1;
            11'd1545:
                alpha = 4'd1;
            11'd1546:
                alpha = 4'd1;
            11'd1547:
                alpha = 4'd1;
            11'd1548:
                alpha = 4'd1;
            11'd1549:
                alpha = 4'd1;
            11'd1550:
                alpha = 4'd1;
            11'd1568:
                alpha = 4'd1;
            11'd1569:
                alpha = 4'd1;
            11'd1570:
                alpha = 4'd1;
            11'd1571:
                alpha = 4'd1;
            11'd1572:
                alpha = 4'd1;
            11'd1573:
                alpha = 4'd1;
            11'd1574:
                alpha = 4'd1;
            11'd1575:
                alpha = 4'd1;
            11'd1576:
                alpha = 4'd1;
            11'd1577:
                alpha = 4'd1;
            11'd1578:
                alpha = 4'd1;
            11'd1579:
                alpha = 4'd1;
            11'd1580:
                alpha = 4'd1;
            11'd1600:
                alpha = 4'd1;
            11'd1601:
                alpha = 4'd1;
            11'd1602:
                alpha = 4'd1;
            11'd1603:
                alpha = 4'd1;
            11'd1604:
                alpha = 4'd1;
            11'd1605:
                alpha = 4'd1;
            11'd1606:
                alpha = 4'd1;
            11'd1607:
                alpha = 4'd1;
            11'd1608:
                alpha = 4'd1;
            11'd1609:
                alpha = 4'd1;
            11'd1610:
                alpha = 4'd1;
            11'd1632:
                alpha = 4'd1;
            11'd1633:
                alpha = 4'd1;
            11'd1634:
                alpha = 4'd1;
            11'd1635:
                alpha = 4'd1;
            11'd1636:
                alpha = 4'd1;
            11'd1637:
                alpha = 4'd1;
            11'd1638:
                alpha = 4'd1;
            11'd1639:
                alpha = 4'd1;
            11'd1640:
                alpha = 4'd1;
            11'd1664:
                alpha = 4'd1;
            11'd1665:
                alpha = 4'd1;
            11'd1666:
                alpha = 4'd1;
            11'd1667:
                alpha = 4'd1;
            11'd1668:
                alpha = 4'd1;
            11'd1669:
                alpha = 4'd1;
            11'd1670:
                alpha = 4'd1;
            11'd1671:
                alpha = 4'd1;
            11'd1672:
                alpha = 4'd1;
            11'd1696:
                alpha = 4'd1;
            11'd1697:
                alpha = 4'd1;
            11'd1698:
                alpha = 4'd1;
            11'd1699:
                alpha = 4'd1;
            11'd1700:
                alpha = 4'd1;
            11'd1701:
                alpha = 4'd1;
            11'd1702:
                alpha = 4'd1;
            11'd1703:
                alpha = 4'd1;
            11'd1704:
                alpha = 4'd1;
            11'd1705:
                alpha = 4'd1;
            11'd1728:
                alpha = 4'd1;
            11'd1729:
                alpha = 4'd1;
            11'd1730:
                alpha = 4'd1;
            11'd1731:
                alpha = 4'd1;
            11'd1732:
                alpha = 4'd1;
            11'd1733:
                alpha = 4'd1;
            11'd1734:
                alpha = 4'd1;
            11'd1735:
                alpha = 4'd1;
            11'd1736:
                alpha = 4'd1;
            11'd1737:
                alpha = 4'd1;
            11'd1738:
                alpha = 4'd1;
            11'd1760:
                alpha = 4'd2;
            11'd1761:
                alpha = 4'd2;
            11'd1762:
                alpha = 4'd2;
            11'd1763:
                alpha = 4'd2;
            11'd1764:
                alpha = 4'd2;
            11'd1765:
                alpha = 4'd2;
            11'd1766:
                alpha = 4'd1;
            11'd1767:
                alpha = 4'd1;
            11'd1768:
                alpha = 4'd1;
            11'd1769:
                alpha = 4'd1;
            11'd1770:
                alpha = 4'd1;
            11'd1771:
                alpha = 4'd1;
            11'd1792:
                alpha = 4'd3;
            11'd1793:
                alpha = 4'd3;
            11'd1794:
                alpha = 4'd3;
            11'd1795:
                alpha = 4'd3;
            11'd1796:
                alpha = 4'd2;
            11'd1797:
                alpha = 4'd2;
            11'd1798:
                alpha = 4'd2;
            11'd1799:
                alpha = 4'd2;
            11'd1800:
                alpha = 4'd1;
            11'd1801:
                alpha = 4'd1;
            11'd1802:
                alpha = 4'd1;
            11'd1803:
                alpha = 4'd1;
            11'd1824:
                alpha = 4'd4;
            11'd1825:
                alpha = 4'd4;
            11'd1826:
                alpha = 4'd4;
            11'd1827:
                alpha = 4'd3;
            11'd1828:
                alpha = 4'd3;
            11'd1829:
                alpha = 4'd3;
            11'd1830:
                alpha = 4'd2;
            11'd1831:
                alpha = 4'd2;
            11'd1832:
                alpha = 4'd2;
            11'd1833:
                alpha = 4'd1;
            11'd1834:
                alpha = 4'd1;
            11'd1835:
                alpha = 4'd1;
            11'd1836:
                alpha = 4'd1;
            11'd1856:
                alpha = 4'd5;
            11'd1857:
                alpha = 4'd5;
            11'd1858:
                alpha = 4'd5;
            11'd1859:
                alpha = 4'd4;
            11'd1860:
                alpha = 4'd4;
            11'd1861:
                alpha = 4'd3;
            11'd1862:
                alpha = 4'd3;
            11'd1863:
                alpha = 4'd2;
            11'd1864:
                alpha = 4'd2;
            11'd1865:
                alpha = 4'd1;
            11'd1866:
                alpha = 4'd1;
            11'd1867:
                alpha = 4'd1;
            11'd1868:
                alpha = 4'd1;
            11'd1888:
                alpha = 4'd6;
            11'd1889:
                alpha = 4'd6;
            11'd1890:
                alpha = 4'd6;
            11'd1891:
                alpha = 4'd5;
            11'd1892:
                alpha = 4'd5;
            11'd1893:
                alpha = 4'd4;
            11'd1894:
                alpha = 4'd3;
            11'd1895:
                alpha = 4'd3;
            11'd1896:
                alpha = 4'd2;
            11'd1897:
                alpha = 4'd2;
            11'd1898:
                alpha = 4'd1;
            11'd1899:
                alpha = 4'd1;
            11'd1900:
                alpha = 4'd1;
            11'd1920:
                alpha = 4'd8;
            11'd1921:
                alpha = 4'd7;
            11'd1922:
                alpha = 4'd7;
            11'd1923:
                alpha = 4'd6;
            11'd1924:
                alpha = 4'd5;
            11'd1925:
                alpha = 4'd5;
            11'd1926:
                alpha = 4'd4;
            11'd1927:
                alpha = 4'd3;
            11'd1928:
                alpha = 4'd2;
            11'd1929:
                alpha = 4'd2;
            11'd1930:
                alpha = 4'd1;
            11'd1931:
                alpha = 4'd1;
            11'd1932:
                alpha = 4'd1;
            11'd1952:
                alpha = 4'd9;
            11'd1953:
                alpha = 4'd9;
            11'd1954:
                alpha = 4'd8;
            11'd1955:
                alpha = 4'd7;
            11'd1956:
                alpha = 4'd6;
            11'd1957:
                alpha = 4'd5;
            11'd1958:
                alpha = 4'd4;
            11'd1959:
                alpha = 4'd3;
            11'd1960:
                alpha = 4'd3;
            11'd1961:
                alpha = 4'd2;
            11'd1962:
                alpha = 4'd1;
            11'd1963:
                alpha = 4'd1;
            11'd1964:
                alpha = 4'd1;
            11'd1984:
                alpha = 4'd10;
            11'd1985:
                alpha = 4'd10;
            11'd1986:
                alpha = 4'd9;
            11'd1987:
                alpha = 4'd8;
            11'd1988:
                alpha = 4'd7;
            11'd1989:
                alpha = 4'd6;
            11'd1990:
                alpha = 4'd5;
            11'd1991:
                alpha = 4'd4;
            11'd1992:
                alpha = 4'd3;
            11'd1993:
                alpha = 4'd2;
            11'd1994:
                alpha = 4'd2;
            11'd1995:
                alpha = 4'd1;
            11'd1996:
                alpha = 4'd1;
            11'd1997:
                alpha = 4'd1;
            11'd2016:
                alpha = 4'd11;
            11'd2017:
                alpha = 4'd11;
            11'd2018:
                alpha = 4'd10;
            11'd2019:
                alpha = 4'd9;
            11'd2020:
                alpha = 4'd7;
            11'd2021:
                alpha = 4'd6;
            11'd2022:
                alpha = 4'd5;
            11'd2023:
                alpha = 4'd4;
            11'd2024:
                alpha = 4'd3;
            11'd2025:
                alpha = 4'd2;
            11'd2026:
                alpha = 4'd2;
            11'd2027:
                alpha = 4'd1;
            11'd2028:
                alpha = 4'd1;
            11'd2029:
                alpha = 4'd1;
            default:
                alpha = 0;
        endcase
    end
endmodule
