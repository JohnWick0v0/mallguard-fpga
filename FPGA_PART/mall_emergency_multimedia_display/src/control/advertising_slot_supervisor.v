// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：常开时段监督：处理SW2/SW3及slot命令，在重置媒体链路时保留实时配置。
// 时钟：clk。
// 复位：本模块无复位端口或本地复位分支。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Always-on supervisor: the selected group and RAM-only settings survive a
// media reload. KEY4 retains the physical slot but uses the usual Flash
// configuration defaults; only a slot reload requests a RAM settings restore.
// Raw switch input is high when UP; logical {SW2,SW3}=~{sw2_n,sw3_n}.
// 设计约定：
// 生命周期约定：本模块属于常开控制域；媒体链路重置时保留时段和实时RAM参数。
// 最终时段切换沿用整链路复位路径，避免直接复用上一文件的读卡/FAT上下文。

module advertising_slot_supervisor #(
    parameter integer SUPPORT_WARM      = 0,
    parameter integer DEBOUNCE_CYCLES = 1000000
)(
    input wire        clk,
    input wire        sw2_n,
                      sw3_n,
    input wire        remote_slot_valid,
    input wire [1:0]  remote_slot,
    input wire        load_busy,
    output reg [7:0]  manual_counter = 0,
    input wire        system_running,
                      control_running,
                      allow_change,
                      config_ready,
    input wire [31:0] live_period_ms,
    input wire [7:0]  live_volume,
                      live_mode,
    input wire [3:0]  live_brightness,
    output reg [1:0]  selected_slot = 0,
    output reg        reload_request = 0,
                      restore_valid = 0,
    output reg [31:0] saved_period_ms = 5000,
    output reg [7:0]  saved_volume = 255,
                      saved_mode = 0,
    output reg [3:0]  saved_brightness = 0
);
    localparam integer CW = DEBOUNCE_CYCLES < 2 ? 1 : $clog2(DEBOUNCE_CYCLES);
    reg [1:0] s1 = 2'b11, s2 = 2'b11, candidate = 0, requested = 0;
    reg [CW - 1:0] stable_count = 0;
    reg [2:0] state             = 0;
    reg restore_pending           = 0;
    generate
        if (SUPPORT_WARM) begin : g_warm
            reg [1:0] desired = 0, physical_q = 0;
            reg force_reload = 0;
            // 产品说明：该监督器位于媒体复位之外；不要在重载时清掉所选时段和已保存的实时设置。
            always @(posedge clk) begin
                s1             <= {sw2_n, sw3_n};
                s2             <= s1;
                reload_request <= 0;
                restore_valid  <= 0;
                if ((~s2) != candidate) begin
                    candidate    <= ~s2;
                    stable_count <= 0;
                end else if (stable_count == DEBOUNCE_CYCLES - 1) begin
                    if (candidate != physical_q) begin
                        physical_q     <= candidate;
                        desired        <= candidate;
                        manual_counter <= manual_counter + 1'b1;
                        force_reload   <= 0;
                    end
                end else
                    stable_count <= stable_count + 1'b1;
                // A physical transition on the same clock has priority.
                if (remote_slot_valid &&
                    !(stable_count == DEBOUNCE_CYCLES - 1 && candidate != physical_q)) begin
                    desired      <= remote_slot;
                    force_reload <= 1;
                end
                case (state)
                    0:
                        if (system_running && control_running && allow_change && config_ready &&
                            (desired != selected_slot || force_reload)) begin
                            selected_slot  <= desired;
                            force_reload   <= 0;
                            reload_request <= 1;
                            state          <= 1;
                        end
                    1:
                        if (load_busy)
                            state <= 2;
                    2:
                        if (!load_busy)
                            state <= 0;
                    default:
                        state <= 0;
                endcase
            end
        end else begin : g_legacy
            // Always-on V24 reset/reload lifecycle, with the V25 host's slot command
            // and physical-switch precedence retained. Capture a physical transition
            // once; a stationary switch must not undo a host-selected time slot.
            reg [1:0] desired = 0, physical_q = 0;
            reg force_reload = 0;
            always @(posedge clk) begin
                s1 <= {sw2_n, sw3_n};
                s2 <= s1;
                if ((~s2) != candidate) begin
                    candidate    <= ~s2;
                    stable_count <= 0;
                end else if (stable_count == DEBOUNCE_CYCLES - 1) begin
                    if (candidate != physical_q) begin
                        physical_q     <= candidate;
                        desired        <= candidate;
                        manual_counter <= manual_counter + 1'b1;
                        force_reload   <= 0;
                    end
                end else
                    stable_count <= stable_count + 1'b1;
                if (remote_slot_valid &&
                    !(stable_count == DEBOUNCE_CYCLES - 1 && candidate != physical_q)) begin
                    desired      <= remote_slot;
                    force_reload <= 1;
                end
                reload_request <= 0;
                restore_valid  <= 0;
                case (state)
                    0:
                        if (system_running && control_running && allow_change && config_ready &&
                            (desired != selected_slot || force_reload)) begin
                            selected_slot    <= desired;
                            force_reload     <= 0;
                            reload_request   <= 1;
                            state            <= 1;
                            restore_pending  <= config_ready;
                            saved_period_ms  <= live_period_ms;
                            saved_volume     <= live_volume;
                            saved_mode       <= live_mode;
                            saved_brightness <= live_brightness;
                        end
                    1:
                        if (!system_running)
                            state <= 2;
                    2:
                        if (system_running && control_running && config_ready) begin
                            restore_valid   <= restore_pending;
                            restore_pending <= 0;
                            state           <= 3;
                        end
                    3:
                        state <= 4;
                    4:
                        state <= 0;
                    default:
                        state <= 0;
                endcase
            end
        end
    endgenerate
endmodule
