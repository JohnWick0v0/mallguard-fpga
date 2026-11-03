// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：在广告右侧叠加约39.6%屏占比通知卡，整束视频延迟一致，应急时隐藏。
// 时钟：sys_clk、clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// 400x304 =39.6% of the active 640x480 image. Geometry is synthesized;
// the full-resolution, host-rasterized text mask occupies one 16KiB dual-clock RAM.
// One cycle of RAM latency is applied to the ENTIRE video bundle.
// 设计约定：
// 合成约定：中文卡片作为独立图层覆盖广告区域，不改写底层SDRAM图片。
// RGB、DE、坐标与同步信号的流水关系必须整体保持。

module finder_notice_overlay (
    input wire         sys_clk,
                       write_en,
    input wire [13:0]  write_address,
    input wire [7:0]   write_data,
    input wire         clk,
                       rst_n,
                       hsync,
                       vsync,
                       de,
    input wire [9:0]   x,
    input wire [23:0]  rgb_in,
    input wire [1:0]   requested_kind,
    input wire         emergency_active,
    output reg [1:0]   shown_kind,
    output reg         hs_out,
                       vs_out,
                       de_out,
    output reg [9:0]   x_out,
    output wire [23:0] rgb_out
);
    wire [7:0] mask_data_q[0:14];
    reg [3:0] read_bank;
    wire [7:0] mask_q = read_bank < 15 ? mask_data_q[read_bank] : 8'd0;
    reg [9:0] y;
    reg vs_q, de_q;
    reg hit_q, accent_q;
    reg [2:0] bit_q;
    reg [1:0] zone_q;
    reg [23:0] rgb_q;
    wire frame_start     = vs_q && !vsync;
    wire [9:0] local_x = x - 10'd232, local_y = y - 10'd88;
    wire inside_card = de && shown_kind != 0 && !emergency_active && x >= 232 && x < 632 &&
                       y >= 88 && y < 392;
    // Rounded corners with a small radius, excluding only the corner pixels.
    wire rounded          = !(local_x < 4 && local_y < 4) && !(local_x >= 396 && local_y < 4) &&
                            !(local_x < 4 && local_y >= 300) && !(local_x >= 396 && local_y >= 300);
    wire [13:0] address = local_y[8:0] * 14'd50 + {7'd0, local_x[8:3]};
    genvar bi;
    generate
        for (bi = 0; bi < 15; bi = bi + 1) begin : g_mask
            reg [7:0] memory[0:1023];
            reg [7:0] q;
            always @(posedge sys_clk)
                if (write_en && write_address[13:10] == bi)
                    memory[write_address[9:0]] <= write_data;
            always @(posedge clk)
                q <= memory[address[9:0]];
            assign mask_data_q[bi] = q;
        end
    endgenerate
    always @(posedge clk)
        read_bank <= address[13:10];
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            y          <= 0;
            vs_q       <= 1;
            de_q       <= 0;
            shown_kind <= 0;
            hs_out     <= 1;
            vs_out     <= 1;
            de_out     <= 0;
            x_out      <= 0;
            hit_q      <= 0;
            accent_q   <= 0;
            bit_q      <= 0;
            zone_q     <= 0;
            rgb_q      <= 0;
        end else begin
            vs_q <= vsync;
            de_q <= de;
            if (!vsync)
                y <= 0;
            else if (de_q && !de)
                y <= y + 1'b1;
            if (frame_start)
                shown_kind <= emergency_active ? 2'd0 : requested_kind;
            hs_out   <= hsync;
            vs_out   <= vsync;
            de_out   <= de;
            x_out    <= x;
            rgb_q    <= rgb_in;
            hit_q    <= inside_card && rounded;
            bit_q    <= 3'd7 - local_x[2:0];
            zone_q   <= local_y < 60 ? 0 : local_y < 188 ? 1 : 2;
            accent_q <= local_x >= 22 && local_x < 26 && local_y >= 214 && local_y < 284;
        end
    wire [23:0] background = zone_q == 2 ? 24'hfaf6ec : 24'h163f3d;
    wire [23:0] foreground = zone_q == 0 ? 24'he9b77c : zone_q == 1 ? 24'hfaf6ec : 24'h163f3d;
    assign rgb_out           = !hit_q          ? rgb_q
                               : accent_q      ? 24'hbd7952
                               : mask_q[bit_q] ? foreground
                                               : background;
endmodule
