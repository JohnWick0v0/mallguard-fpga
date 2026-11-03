// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：按广告/缩略图/视频上下文映射四键；KEY1+KEY2约2秒请求保存。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// Context-dependent UI. Parameter updates go through the existing Flash
// service's live-config port; only the KEY1+KEY2 chord requests a write.
// 产品说明：普通/缩略图/视频共用按键。组合键优先抑制单键副作用；长按不应再次产生短按。
module display_key_controller #(
    parameter integer SUPPORT_INHIBIT   = 0,
    parameter integer DEBOUNCE_CYCLES = 1000000,
    parameter integer LONG_CYCLES     = 50000000,
    parameter integer SAVE_CYCLES     = 100000000
)(
    input wire        clk,
                      rst_n,
    input wire        inhibit,
                      video_mode,
    output wire       video_pause_event,
    input wire [3:0]  keys_n,
    input wire        service_ready,
                      player_ready,
    input wire [1:0]  active_index,
    input wire [7:0]  live_volume,
    input wire [31:0] live_period_ms,
    input wire        auto_enabled,
    output reg        thumbnail_mode,
    output reg [1:0]  focus_index,
    output reg        next_event,
                      prev_event,
                      select_event,
    output reg        brightness_event,
    output wire       reset_request,
    output wire       save_event,
    output wire       save_locked,
    output reg        cfg_valid,
    output reg [7:0]  cfg_volume,
                      cfg_mode,
    output reg [31:0] cfg_period_ms,
    output reg        menu_event,
    output reg [1:0]  menu_kind
);
    wire [3:0] short_key, long_key;
    wire chord_save;
    four_key_event_router #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),
        .LONG_CYCLES(LONG_CYCLES),
        .SAVE_CYCLES(SAVE_CYCLES)
    ) u_events (
        .clk(clk),
        .rst_n(rst_n && !(SUPPORT_INHIBIT && inhibit)),
        .keys_n(keys_n),
        .save_enabled(service_ready),
        .short_event(short_key),
        .long_event(long_key),
        .save_event(chord_save),
        .chord_locked(save_locked)
    );
    assign video_pause_event = video_mode && short_key[0];
    assign reset_request     = long_key[3];
    assign save_event        = chord_save;

    function [7:0] next_volume;
        input [7:0] value;
        begin
            case (value)
                8'd0:
                    next_volume = 64;
                8'd64:
                    next_volume = 128;
                8'd128:
                    next_volume = 192;
                8'd192:
                    next_volume = 255;
                default:
                    next_volume = 0;
            endcase
        end
    endfunction
    function [31:0] next_period;
        input [31:0] value;
        begin
            if (value < 3500)
                next_period = 5000;
            else if (value < 7500)
                next_period = 10000;
            else if (value < 20000)
                next_period = 30000;
            else
                next_period = 2000;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            thumbnail_mode   <= 0;
            focus_index      <= 0;
            next_event       <= 0;
            prev_event       <= 0;
            select_event     <= 0;
            brightness_event <= 0;
            cfg_valid        <= 0;
            cfg_volume       <= 255;
            cfg_mode         <= 0;
            cfg_period_ms    <= 5000;
            menu_event       <= 0;
            menu_kind        <= 0;
        end else begin
            next_event       <= 0;
            prev_event       <= 0;
            select_event     <= 0;
            brightness_event <= 0;
            cfg_valid        <= 0;
            menu_event       <= 0;
            // Freeze UI changes for the whole chord so the registered
            // config-update port cannot collide with its Flash snapshot.
            if (!(SUPPORT_INHIBIT && inhibit) && !chord_save && !save_locked) begin
                if (player_ready) begin
                    if (long_key[2] && !video_mode) begin
                        thumbnail_mode <= ~thumbnail_mode;
                        if (!thumbnail_mode)
                            focus_index <= active_index;
                    end else if (thumbnail_mode && !video_mode) begin
                        if (short_key[2]) begin
                            select_event   <= 1;
                            thumbnail_mode <= 0;
                        end else if (short_key[0])
                            focus_index <= focus_index + 2'd1;
                        else if (short_key[1])
                            focus_index <= focus_index - 2'd1;
                    end else begin
                        if (short_key[0])
                            next_event <= 1;
                        else if (short_key[1])
                            prev_event <= 1;
                        if (short_key[3])
                            brightness_event <= 1;
                    end
                end
                if (service_ready && (!thumbnail_mode || video_mode) && !long_key[2]) begin
                    cfg_volume    <= live_volume;
                    cfg_period_ms <= live_period_ms;
                    cfg_mode      <= {7'd0, auto_enabled};
                    if (long_key[0]) begin
                        cfg_valid <= 1;
                        cfg_mode  <= {7'd0, ~auto_enabled};
                    end else if (long_key[1]) begin
                        cfg_valid     <= 1;
                        cfg_period_ms <= next_period(live_period_ms);
                        menu_event    <= 1;
                        menu_kind     <= 1;
                    end else if (short_key[2]) begin
                        cfg_valid  <= 1;
                        cfg_volume <= next_volume(live_volume);
                        menu_event <= 1;
                        menu_kind  <= 0;
                    end
                end
            end
        end
    end
endmodule
