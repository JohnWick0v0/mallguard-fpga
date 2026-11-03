// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：兼容维护控制器：协调停止、保留帧、重新装载与提交；最终时段主路径为整链路复位。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）；storage_reset（向子模块传递，语义见子模块）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// No PLL, SDRAM, video reader, configuration or emergency reset on slot reload.
// Quiesce -> cache old frame -> show cache -> ingest -> gallery -> frame commit.
// 设计约定：
// 兼容约定：该控制器保留暖重载维护路径；最终时段主路径仍由稳定整链路复位接管。

module media_reload_controller #(
    parameter integer CLOCK_HZ = 80000000,
                      TIMEOUT_MS = 30000
)(
    input wire       clk,
                     rst_n,
                     request_toggle,
                     front_ready,
                     dma_idle,
                     storage_idle,
                     controller_idle,
                     frame_tick,
    input wire       copy_done,
                     ingest_done,
                     ingest_ok,
                     gallery_done,
                     gallery_ok,
    input wire [3:0] image_complete,
    output wire      active,
                     loading,
                     hold_view,
                     stream_stop,
                     stream_clear,
                     storage_reset,
    output reg       copy_start,
                     load_start,
                     gallery_start,
                     done,
    output reg [7:0] error_code,
    output reg [7:0] progress
);
    reg req_sync1_mem, req_sync2_mem, seen, cache_valid;
    reg [3:0] quiet;
    reg [3:0] state;
    reg [1:0] frames;
    localparam IDLE = 0, QUIESCE = 1, COPY = 2, HOLD = 3, LOAD = 4, GALLERY = 5, COMMIT = 6,
               FAILED           = 7;
    localparam integer TICK_MAX = CLOCK_HZ / 1000 - 1, TW = $clog2(CLOCK_HZ / 1000);
    reg [TW - 1:0] tick;
    reg [14:0] elapsed;
    assign active        = state != IDLE;
    assign loading       = state != IDLE && state != FAILED;
    assign hold_view     = cache_valid && state != IDLE && state != COMMIT;
    assign stream_stop   = state != IDLE;
    assign stream_clear  = state >= COPY;
    assign storage_reset = state == COPY || state == HOLD;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            quiet         <= 0;
            cache_valid   <= 0;
            req_sync1_mem <= 0;
            req_sync2_mem <= 0;
            seen          <= 0;
            state         <= IDLE;
            frames        <= 0;
            tick          <= 0;
            elapsed       <= 0;
            copy_start    <= 0;
            load_start    <= 0;
            gallery_start <= 0;
            done          <= 0;
            error_code    <= 0;
            progress      <= 0;
        end else begin
            req_sync1_mem <= request_toggle;
            req_sync2_mem <= req_sync1_mem;
            if (state == QUIESCE && dma_idle && storage_idle && controller_idle) begin
                if (quiet < 8)
                    quiet <= quiet + 1'b1;
            end else
                quiet <= 0;
            copy_start    <= 0;
            load_start    <= 0;
            gallery_start <= 0;
            done          <= 0;
            if (loading) begin
                if (tick == TICK_MAX) begin
                    tick    <= 0;
                    elapsed <= elapsed + 1'b1;
                end else
                    tick <= tick + 1'b1;
            end else begin
                tick    <= 0;
                elapsed <= 0;
            end
            case (state)
                IDLE:
                    if (req_sync2_mem != seen && front_ready) begin
                        seen       <= req_sync2_mem;
                        state      <= QUIESCE;
                        error_code <= 0;
                        progress   <= 1;
                    end
                QUIESCE:
                    if (quiet == 8 && dma_idle && storage_idle && controller_idle) begin
                        copy_start <= 1;
                        state      <= COPY;
                        progress   <= 3;
                    end
                COPY:
                    if (copy_done) begin
                        cache_valid <= 1;
                        state       <= HOLD;
                        frames      <= 0;
                        progress    <= 8;
                    end
                HOLD:
                    if (frame_tick) begin
                        if (frames == 1) begin
                            load_start <= 1;
                            state      <= LOAD;
                            progress   <= 10;
                        end else
                            frames <= frames + 1'b1;
                    end
                LOAD: begin
                    progress <= 10 + ({7'd0, image_complete[0]} + {7'd0, image_complete[1]} +
                                         {7'd0, image_complete[2]} + {7'd0, image_complete[3]}) *
                                         8'd17;
                    if (ingest_done) begin
                        if (ingest_ok) begin
                            gallery_start <= 1;
                            state         <= GALLERY;
                            progress      <= 80;
                        end else begin
                            state      <= FAILED;
                            error_code <= 8'hb6;
                        end
                    end
                end
                GALLERY:
                    if (gallery_done) begin
                        if (gallery_ok) begin
                            state    <= COMMIT;
                            frames   <= 0;
                            progress <= 98;
                        end else begin
                            state      <= FAILED;
                            error_code <= 8'hb7;
                        end
                    end
                COMMIT:
                    if (frame_tick) begin
                        if (frames == 2 && dma_idle) begin
                            state       <= IDLE;
                            cache_valid <= 0;
                            done        <= 1;
                            progress    <= 100;
                        end else if (frames != 2)
                            frames <= frames + 1'b1;
                    end
                FAILED:
                    if (req_sync2_mem != seen && dma_idle && storage_idle && controller_idle) begin
                        seen       <= req_sync2_mem;
                        state      <= cache_valid ? HOLD : COPY;
                        frames     <= 0;
                        copy_start <= !cache_valid;
                        error_code <= 0;
                        progress   <= 3;
                    end
                default:
                    state <= IDLE;
            endcase
            if (loading && elapsed >= TIMEOUT_MS) begin
                state      <= FAILED;
                error_code <= 8'hb8;
            end
        end
endmodule
