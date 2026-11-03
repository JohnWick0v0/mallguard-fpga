// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：仲裁背景音乐、广播与视频等读扇区请求，保持完整扇区事务的归属。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Both clients pulse requests after observing !busy. Keep one request slot
// for each client so simultaneous registered pulses cannot be lost. Ownership
// is held through the last data byte and sector_done, never switched on mode.
// 设计约定：
// 仲裁约定：已获准的客户端持续拥有当前完整扇区，不能在字节流中途切换归属。

module audio_sector_arbiter (
    input wire        clk,
                      rst_n,
    input wire        a_req,
    input wire [31:0] a_lba,
    output wire       a_busy,
                      a_valid,
                      a_done,
    input wire        b_req,
    input wire [31:0] b_lba,
    output wire       b_busy,
                      b_valid,
                      b_done,
    output reg        sector_req,
    output reg [31:0] sector_lba,
    input wire        sector_busy,
                      sector_valid,
                      sector_done
);
    reg pending_a, pending_b, locked, owner, prefer_b;
    reg [31:0] lba_a, lba_b;
    assign a_busy  = pending_a || (locked && !owner);
    assign b_busy  = pending_b || (locked && owner);
    assign a_valid = locked && !owner && sector_valid;
    assign b_valid = locked && owner && sector_valid;
    assign a_done  = locked && !owner && sector_done;
    assign b_done  = locked && owner && sector_done;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            pending_a  <= 0;
            pending_b  <= 0;
            locked     <= 0;
            owner      <= 0;
            prefer_b   <= 0;
            lba_a      <= 0;
            lba_b      <= 0;
            sector_req <= 0;
            sector_lba <= 0;
        end else begin
            sector_req <= 0;
            if (a_req) begin
                pending_a <= 1;
                lba_a     <= a_lba;
            end
            if (b_req) begin
                pending_b <= 1;
                lba_b     <= b_lba;
            end
            if (locked) begin
                if (sector_done) begin
                    locked   <= 0;
                    prefer_b <= !owner;
                end
            end else if (!sector_busy && !sector_req && (pending_a || pending_b)) begin
                locked     <= 1;
                sector_req <= 1;
                if (pending_b && (!pending_a || prefer_b)) begin
                    owner      <= 1;
                    sector_lba <= lba_b;
                    pending_b  <= 0;
                end else begin
                    owner      <= 0;
                    sector_lba <= lba_a;
                    pending_a  <= 0;
                end
            end
        end
endmodule
