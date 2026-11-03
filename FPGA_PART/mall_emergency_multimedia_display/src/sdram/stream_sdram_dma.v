// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：仲裁显示读、媒体写与视频突发事务，明确返回数据归属。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Complete bounded transactions. Separate SD-input and decoded-frame writers
// prevent a slow card or a paused player from corrupting either FIFO.
module stream_sdram_dma (
    input wire         clk,
                       rst_n,
                       init_done,
                       controller_busy,
                       refresh,
    input wire         v_req,
    input wire [7:0]   v_count,
    output wire        v_grant,
    input wire         v_en,
    input wire [20:0]  v_addr,
    input wire         a_req,
    input wire [7:0]   a_count,
    input wire [20:0]  a_addr,
    output wire        a_grant,
    output reg         a_done,
    input wire         p_req,
    input wire [20:0]  p_addr,
    output wire        p_grant,
    input wire         s_req,
                       s_valid,
    input wire [31:0]  s_data,
    input wire [20:0]  s_addr,
    output wire        s_pop,
    output wire        s_grant,
    output reg         s_done,
    input wire         d_req,
                       d_valid,
    input wire [31:0]  d_data,
    input wire [20:0]  d_addr,
    output wire        d_pop,
    output wire        d_grant,
    output reg         d_done,
    output wire        app_rd_en,
    output wire [20:0] app_rd_addr,
    output wire        app_wr_en,
    output wire [20:0] app_wr_addr,
    output wire [31:0] app_wr_data,
    input wire         rd_valid,
    input wire [31:0]  rd_data,
    output wire        video_return,
                       audio_return,
                       packet_return,
    output wire [31:0] return_data,
    output wire        idle,
    output reg [7:0]   error
);
    localparam NONE = 0, VIDEO = 1, AUDIO = 2, PACKET = 3, SDWRITE = 4, DECODE = 5;
    reg [2:0] owner;
    reg [7:0] issued, returned, target;
    reg [4:0] gap;
    reg [20:0] base;
    reg [17:0] watchdog;
    wire admit     = owner == NONE && gap == 0 && init_done && !controller_busy && !refresh;
    assign v_grant = admit && v_req;
    assign a_grant = admit && !v_req && a_req;
    assign s_grant = admit && !v_req && !a_req && s_req;
    assign d_grant = admit && !v_req && !a_req && !s_req && d_req;
    assign p_grant = admit && !v_req && !a_req && !s_req && !d_req && p_req;
    assign idle    = owner == NONE && gap == 0;
    assign app_rd_en =
               owner == VIDEO ? v_en : (owner == AUDIO || owner == PACKET) && issued < target;
    assign app_rd_addr   = owner == VIDEO ? v_addr : base + issued;
    assign app_wr_en     = (owner == SDWRITE || owner == DECODE) && issued < target &&
                           (owner == SDWRITE ? s_valid : d_valid);
    assign app_wr_addr   = base + issued;
    assign app_wr_data   = owner == SDWRITE ? s_data : d_data;
    assign s_pop         = app_wr_en && owner == SDWRITE;
    assign d_pop         = app_wr_en && owner == DECODE;
    assign video_return  = rd_valid && owner == VIDEO;
    assign audio_return  = rd_valid && owner == AUDIO;
    assign packet_return = rd_valid && owner == PACKET;
    assign return_data   = rd_data;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            owner    <= NONE;
            issued   <= 0;
            returned <= 0;
            target   <= 0;
            gap      <= 0;
            base     <= 0;
            watchdog <= 0;
            error    <= 0;
            a_done   <= 0;
            s_done   <= 0;
            d_done   <= 0;
        end else begin
            a_done <= 0;
            s_done <= 0;
            d_done <= 0;
            if (gap != 0)
                gap <= gap - 1'b1;
            if (owner != NONE)
                watchdog <= watchdog + 1'b1;
            else
                watchdog <= 0;
            if (v_grant || a_grant || s_grant || d_grant || p_grant) begin
                owner    <= v_grant   ? VIDEO
                            : a_grant ? AUDIO
                            : s_grant ? SDWRITE
                            : d_grant ? DECODE
                                      : PACKET;
                target   <= v_grant                ? v_count
                            : a_grant              ? a_count
                            : (s_grant || d_grant) ? 8'd128
                                                   : 8'd64;
                base     <= a_grant ? a_addr : s_grant ? s_addr : d_grant ? d_addr : p_addr;
                issued   <= 0;
                returned <= 0;
            end
            if (owner == VIDEO && v_en)
                issued <= issued + 1'b1;
            if ((owner == AUDIO || owner == PACKET) && app_rd_en)
                issued <= issued + 1'b1;
            if (rd_valid && owner != NONE && owner != SDWRITE && owner != DECODE) begin
                returned <= returned + 1'b1;
                if (returned + 1'b1 == target) begin
                    if (owner == AUDIO)
                        a_done <= 1;
                    owner <= NONE;
                    gap   <= 12;
                end
            end
            if (owner == SDWRITE || owner == DECODE) begin
                if (app_wr_en) begin
                    issued <= issued + 1'b1;
                    if (issued + 1'b1 == target)
                        gap <= 12;
                end
                if (issued == target && gap == 0 && !controller_busy) begin
                    if (owner == SDWRITE)
                        s_done <= 1;
                    else
                        d_done <= 1;
                    owner <= NONE;
                end
                if (issued < target && !(owner == SDWRITE ? s_valid : d_valid))
                    error <= 8'hc2;
            end
            if (watchdog == 18'h3ffff) begin
                error <= 8'hc1;
                owner <= NONE;
            end
        end
    end
endmodule
