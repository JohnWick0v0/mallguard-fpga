// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：四键事件分发接口，保留去抖后的按键状态与事件。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

// Keys 1/2 resolve on release so a late second key can cancel the complete
// single-key gesture. A chord consumes both keys until BOTH are released,
// even if it is too short or Flash is not ready. No repeat while held.
module four_key_event_router #(
    parameter integer DEBOUNCE_CYCLES = 1000000,
    parameter integer LONG_CYCLES   = 50000000,
    parameter integer SAVE_CYCLES   = 100000000
)(
    input wire       clk,
                     rst_n,
    input wire [3:0] keys_n,
    input wire       save_enabled,
    output reg [3:0] short_event,
    output reg [3:0] long_event,
    output reg       save_event,
    output reg       chord_locked
);
    localparam integer DB_W   = DEBOUNCE_CYCLES < 2 ? 1 : $clog2(DEBOUNCE_CYCLES);
    localparam integer LONG_W = LONG_CYCLES < 2 ? 1 : $clog2(LONG_CYCLES + 1);
    localparam integer SAVE_W = SAVE_CYCLES < 2 ? 1 : $clog2(SAVE_CYCLES + 1);
    (* async_reg = "true" *) reg [3:0] sync1, sync2;
    reg [3:0] stable_n;
    reg [DB_W - 1:0] db_count[0:3];
    reg [LONG_W - 1:0] hold_count[0:3];
    reg [3:0] active;
    reg [3:0] long_sent;
    reg armed;
    reg [SAVE_W - 1:0] chord_count;
    reg chord_sent;
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1        <= 4'hf;
            sync2        <= 4'hf;
            stable_n     <= 4'hf;
            short_event  <= 0;
            long_event   <= 0;
            save_event   <= 0;
            active       <= 0;
            long_sent    <= 0;
            armed        <= 0;
            chord_locked <= 0;
            chord_count  <= 0;
            chord_sent   <= 0;
            for (i = 0; i < 4; i = i + 1) begin
                db_count[i]   <= 0;
                hold_count[i] <= 0;
            end
        end else begin
            sync1       <= keys_n;
            sync2       <= sync1;
            short_event <= 0;
            long_event  <= 0;
            save_event  <= 0;
            for (i = 0; i < 4; i = i + 1) begin
                if (sync2[i] == stable_n[i])
                    db_count[i] <= 0;
                else if (db_count[i] == DEBOUNCE_CYCLES - 1) begin
                    stable_n[i] <= sync2[i];
                    db_count[i] <= 0;
                end else
                    db_count[i] <= db_count[i] + 1'b1;
            end

            // Wait for synchronization/debounce to settle after reset. Raw
            // and synchronized keys must all be released before rearming.
            if (!armed) begin
                if (&keys_n && &sync1 && &sync2 && &stable_n)
                    armed <= 1;
            end else begin
                for (i = 0; i < 4; i = i + 1) begin
                    if (i < 2 && (chord_locked || stable_n[1:0] == 2'b00)) begin
                        active[i]     <= 0;
                        hold_count[i] <= 0;
                        long_sent[i]  <= 0;
                    end else if (!stable_n[i]) begin
                        if (!active[i]) begin
                            active[i]     <= 1;
                            hold_count[i] <= 0;
                            long_sent[i]  <= 0;
                        end else if (hold_count[i] < LONG_CYCLES) begin
                            hold_count[i] <= hold_count[i] + 1'b1;
                            // Keys 3/4 are safe to trigger at the threshold;
                            // keys 1/2 must wait until release for chord priority.
                            if (i >= 2 && hold_count[i] == LONG_CYCLES - 1) begin
                                long_event[i] <= 1;
                                long_sent[i]  <= 1;
                            end
                        end
                    end else if (active[i]) begin
                        active[i]     <= 0;
                        hold_count[i] <= 0;
                        long_sent[i]  <= 0;
                        if (!long_sent[i]) begin
                            if (hold_count[i] >= LONG_CYCLES)
                                long_event[i] <= 1;
                            else
                                short_event[i] <= 1;
                        end
                    end
                end

                if (!chord_locked && stable_n[1:0] == 2'b00) begin
                    chord_locked <= 1;
                    chord_count  <= 0;
                    chord_sent   <= 0;
                end else if (chord_locked) begin
                    if (stable_n[1:0] == 2'b11) begin
                        chord_locked <= 0;
                        chord_count  <= 0;
                        chord_sent   <= 0;
                    end else if (stable_n[1:0] != 2'b00) begin
                        // An interrupted hold cannot resume while one key
                        // remains pressed. Release both to start a new chord.
                        chord_count <= 0;
                        chord_sent  <= 1;
                    end else if (!chord_sent) begin
                        if (chord_count == SAVE_CYCLES - 1) begin
                            chord_sent <= 1;
                            if (save_enabled)
                                save_event <= 1;
                        end else
                            chord_count <= chord_count + 1'b1;
                    end
                end
            end
        end
    end
endmodule
