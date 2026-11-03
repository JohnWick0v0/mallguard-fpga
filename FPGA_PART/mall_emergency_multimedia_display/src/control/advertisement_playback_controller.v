// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：控制广告图片索引、A/E自动轮播周期和切图提交。
// 时钟：sys_clk、pix_clk。
// 复位：sys_rst_n（低有效异步复位）；pix_rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

module advertisement_playback_controller #(
    parameter integer SUPPORT_FREEZE           = 0,
    parameter [31:0]  DEFAULT_PERIOD_CYCLES = 32'd250000000,
    parameter [31:0]  MIN_PERIOD_CYCLES     = 32'd50000000,
    parameter [31:0]  MAX_PERIOD_CYCLES     = 32'd3000000000
)(
    input wire        sys_clk,
    input wire        sys_rst_n,
    input wire        freeze_state,
    input wire        prev_event,
                      select_event,
                      pause_auto,
    input wire [1:0]  select_index,
    input wire        next_event,
    input wire        toggle_auto_event,
    input wire        period_cfg_valid,
    input wire [31:0] period_cfg_cycles,
    input wire        auto_cfg_valid,
    input wire        auto_cfg_enabled,
    input wire [3:0]  image_complete,
    output reg        auto_enabled,
    output reg [31:0] active_period_cycles,
    output reg [1:0]  pending_index,
    output reg [7:0]  control_error,
    output wire       request_busy,
    input wire        pix_clk,
    input wire        pix_rst_n,
    input wire        frame_start,
    output reg [1:0]  active_index,
    output reg        index_commit
);
    localparam ERR_NONE         = 8'h00;
    localparam ERR_PERIOD_RANGE = 8'h51;
    localparam ERR_REQUEST_BUSY = 8'h52;
    localparam ERR_NO_RESOURCE  = 8'h53;

    reg [31:0] auto_counter;
    reg [1:0] sys_current_index;
    reg request_toggle;
    reg ack_toggle_pix;
    reg ack_sync1, ack_sync2;
    reg [1:0] index_sync1, index_sync2;
    reg req_sync1, req_sync2;
    reg req_seen_pix;
    reg commit_pending_pix;
    wire frozen = SUPPORT_FREEZE && freeze_state;
    (* async_reg = "true" *) reg freeze_s1, freeze_s2;

    assign request_busy = request_toggle != ack_sync2;

    function [2:0] next_available;
        input [1:0] current;
        input [3:0] complete;
        integer step;
        reg [1:0] candidate;
        begin
            next_available = {1'b0, current};
            for (step = 1; step <= 4; step = step + 1) begin
                candidate = current + step[1:0];
                if (!next_available[2] && complete[candidate])
                    next_available = {1'b1, candidate};
            end
        end
    endfunction

    task issue_selected;
        input [1:0] target;
        begin
            if (request_busy)
                control_error <= ERR_REQUEST_BUSY;
            else if (!image_complete[target])
                control_error <= ERR_NO_RESOURCE;
            else begin
                pending_index  <= target;
                request_toggle <= ~request_toggle;
                auto_counter   <= 0;
                control_error  <= 0;
            end
        end
    endtask
    task issue_next_request;
        reg [2:0] selected;
        begin
            selected = next_available(sys_current_index, image_complete);
            if (request_busy) begin
                control_error <= ERR_REQUEST_BUSY;
            end else if (!selected[2]) begin
                control_error <= ERR_NO_RESOURCE;
            end else begin
                pending_index  <= selected[1:0];
                request_toggle <= ~request_toggle;
                auto_counter   <= 32'd0;
                // A successful issue retires any earlier sticky fault
                // (REQUEST_BUSY / NO_RESOURCE from boot-time presses), so the
                // OSD/UART error code reflects the latest outcome instead of
                // latching forever.
                control_error <= ERR_NONE;
            end
        end
    endtask

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            auto_enabled         <= 1'b0;
            active_period_cycles <= DEFAULT_PERIOD_CYCLES;
            pending_index        <= 2'd0;
            control_error        <= ERR_NONE;
            auto_counter         <= 32'd0;
            sys_current_index    <= 2'd0;
            request_toggle       <= 1'b0;
            ack_sync1            <= 1'b0;
            ack_sync2            <= 1'b0;
        end else begin
            ack_sync1 <= ack_toggle_pix;
            ack_sync2 <= ack_sync1;
            if (!request_busy)
                sys_current_index <= pending_index;

            if (!frozen) begin
                if (period_cfg_valid) begin
                    if (period_cfg_cycles < MIN_PERIOD_CYCLES ||
                        period_cfg_cycles > MAX_PERIOD_CYCLES) begin
                        control_error <= ERR_PERIOD_RANGE;
                    end else begin
                        active_period_cycles <= period_cfg_cycles;
                        auto_counter         <= 32'd0;
                    end
                end

                if (auto_cfg_valid) begin
                    auto_enabled <= auto_cfg_enabled;
                    auto_counter <= 32'd0;
                end

                if (toggle_auto_event) begin
                    auto_enabled <= ~auto_enabled;
                    auto_counter <= 32'd0;
                end

                if (select_event) begin
                    issue_selected(select_index);
                end else if (prev_event) begin
                    issue_selected(sys_current_index - 2'd1);
                end else if (next_event) begin
                    issue_next_request();
                end else if (auto_enabled && !pause_auto) begin
                    if (request_busy)
                        auto_counter <= 32'd0;
                    else if (auto_counter >= active_period_cycles - 1'b1)
                        issue_next_request();
                    else
                        auto_counter <= auto_counter + 1'b1;
                end else begin
                    auto_counter <= 32'd0;
                end
            end
        end
    end

    always @(posedge pix_clk or negedge pix_rst_n) begin
        if (!pix_rst_n) begin
            index_sync1        <= 2'd0;
            index_sync2        <= 2'd0;
            req_sync1          <= 1'b0;
            req_sync2          <= 1'b0;
            req_seen_pix       <= 1'b0;
            commit_pending_pix <= 1'b0;
            active_index       <= 2'd0;
            index_commit       <= 1'b0;
            ack_toggle_pix     <= 1'b0;
            freeze_s1          <= 0;
            freeze_s2          <= 0;
        end else begin
            freeze_s1    <= frozen;
            freeze_s2    <= freeze_s1;
            index_sync1  <= pending_index;
            index_sync2  <= index_sync1;
            req_sync1    <= request_toggle;
            req_sync2    <= req_sync1;
            index_commit <= 1'b0;

            // Sample the bank index at the frame_start commit, not when the
            // request toggle is detected. pending_index and request_toggle
            // launch on the same sys_clk edge through independent 2FF chains,
            // so index_sync2 can lag the toggle at detection time. By
            // frame_start the value has settled for a whole frame period and
            // cannot change again: issue_next_request is blocked by
            // request_busy until the ack sent at this very commit.
            if (req_sync2 != req_seen_pix && !commit_pending_pix) begin
                req_seen_pix       <= req_sync2;
                commit_pending_pix <= 1'b1;
            end

            if (frame_start && commit_pending_pix && !freeze_s2) begin
                active_index       <= index_sync2;
                index_commit       <= 1'b1;
                commit_pending_pix <= 1'b0;
                ack_toggle_pix     <= req_seen_pix;
            end
        end
    end
endmodule
