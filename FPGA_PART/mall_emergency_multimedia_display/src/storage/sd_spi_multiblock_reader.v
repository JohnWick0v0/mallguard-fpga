// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：多扇区连续读取，维护起止、令牌、数据及停止流程。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// CMD18 stays open across consecutive sector requests, with SCLK paused low
// between requests. CMD12 (stuff byte, R1, busy release) precedes every seek.
module sd_spi_multiblock_reader #(
    parameter integer SUPPORT_QUIESCE = 0,
    parameter integer SPI_CLK_DIV   = 1,
                      MAX_R1_BYTES                    = 16,
                      MAX_TOKEN_BYTES                 = 32768,
                      MAX_BUSY_BYTES                  = 32768,
    parameter         CHECK_DATA_CRC        = 1'b1
)(
    input wire        clk,
                      rst_n,
                      init_ready,
                      card_high_capacity,
                      sector_req,
    input wire [31:0] sector_lba,
    input wire        quiesce,
    output wire       sector_busy,
    output reg        sector_done,
                      sector_valid,
    output reg [7:0]  sector_byte,
    output reg [8:0]  sector_byte_index,
    output reg [7:0]  sector_error,
                      last_r1,
    output wire       sd_cs_n,
                      sd_sclk,
                      sd_mosi,
    input wire        sd_miso
);
    localparam IDLE = 0, PRE_REQ = 1, PRE_WAIT = 2, CMD_REQ = 3, CMD_WAIT = 4, R1_REQ = 5,
               R1_WAIT = 6, TOKEN_REQ = 7, TOKEN_WAIT = 8, DATA_REQ = 9, DATA_WAIT = 10,
               CRC_H_REQ = 11, CRC_H_WAIT = 12, CRC_L_REQ = 13, CRC_L_WAIT = 14, POST_REQ = 15,
               POST_WAIT = 16, STUFF_REQ = 17, STUFF_WAIT = 18, BUSY_REQ = 19, BUSY_WAIT = 20;
    reg [4:0] state;
    reg multi_active, is_stop, restarting, close_only;
    reg [31:0] held_lba, next_lba, command_argument;
    reg [2:0] cmd_index;
    reg [8:0] data_count;
    reg [15:0] data_crc;
    reg [7:0] crc_high;
    reg [15:0] poll_count;
    reg byte_start;
    reg [7:0] byte_tx;
    wire byte_busy, byte_done;
    wire [7:0] byte_rx;
    assign sector_busy = state != IDLE;
    assign sd_cs_n     = !multi_active && (state == IDLE || state == PRE_REQ || state == PRE_WAIT ||
                                              state == POST_REQ || state == POST_WAIT);
    sd_spi_byte_engine #(
        .CLK_DIV(SPI_CLK_DIV)
    ) u_byte_engine (
        .clk(clk),
        .rst_n(rst_n),
        .start(byte_start),
        .tx_byte(byte_tx),
        .miso(sd_miso),
        .busy(byte_busy),
        .done(byte_done),
        .rx_byte(byte_rx),
        .sclk(sd_sclk),
        .mosi(sd_mosi)
    );
    function [7:0] command_byte;
        input [2:0] i;
        begin
            case (i)
                0:
                    command_byte = is_stop ? 8'h4c : 8'h52;
                1:
                    command_byte = command_argument[31:24];
                2:
                    command_byte = command_argument[23:16];
                3:
                    command_byte = command_argument[15:8];
                4:
                    command_byte = command_argument[7:0];
                default:
                    command_byte = 8'hff;
            endcase
        end
    endfunction
    function [15:0] crc16_byte;
        input [15:0] c;
        input [7:0] b;
        integer i;
        reg [15:0] v;
        begin
            v = c;
            for (i = 0; i < 8; i = i + 1)
                v = (v[15] ^ b[7 - i]) ? {v[14:0], 1'b0} ^ 16'h1021 : {v[14:0], 1'b0};
            crc16_byte = v;
        end
    endfunction
    task fail;
        input [7:0] e;
        begin
            sector_error <= e;
            restarting   <= 0;
            if (multi_active) begin
                is_stop          <= 1;
                cmd_index        <= 0;
                command_argument <= 0;
                byte_tx          <= 8'h4c;
                state            <= CMD_REQ;
            end else
                state <= POST_REQ;
        end
    endtask
    task stop_failed;
        begin
            sector_error <= 8'h07;
            multi_active <= 0;
            restarting   <= 0;
            state        <= POST_REQ;
        end
    endtask
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= IDLE;
            multi_active      <= 0;
            is_stop           <= 0;
            restarting        <= 0;
            close_only        <= 0;
            held_lba          <= 0;
            next_lba          <= 0;
            command_argument  <= 0;
            cmd_index         <= 0;
            data_count        <= 0;
            data_crc          <= 0;
            crc_high          <= 0;
            poll_count        <= 0;
            byte_start        <= 0;
            byte_tx           <= 8'hff;
            sector_done       <= 0;
            sector_valid      <= 0;
            sector_byte       <= 0;
            sector_byte_index <= 0;
            sector_error      <= 0;
            last_r1           <= 8'hff;
        end else begin
            byte_start   <= 0;
            sector_done  <= 0;
            sector_valid <= 0;
            case (state)
                IDLE:
                    if (sector_req) begin
                        close_only   <= 0;
                        sector_error <= 0;
                        last_r1      <= 8'hff;
                        held_lba     <= sector_lba;
                        data_count   <= 0;
                        data_crc     <= 0;
                        poll_count   <= 0;
                        if (!init_ready) begin
                            sector_error <= 8'h06;
                            sector_done  <= 1;
                        end else if (multi_active && sector_lba == next_lba)
                            state <= TOKEN_REQ;
                        else if (multi_active) begin
                            is_stop          <= 1;
                            restarting       <= 1;
                            command_argument <= 0;
                            cmd_index        <= 0;
                            byte_tx          <= 8'h4c;
                            state            <= CMD_REQ;
                        end else begin
                            is_stop          <= 0;
                            restarting       <= 0;
                            command_argument <= card_high_capacity ? sector_lba : sector_lba << 9;
                            cmd_index        <= 0;
                            state            <= PRE_REQ;
                        end
                    end else if (SUPPORT_QUIESCE && quiesce && multi_active) begin
                        // A paused CMD18 keeps CS low even though sector_busy is already low.
                        // Finish the open stream with CMD12, its stuff byte, R1b and post clocks.
                        // This is not a new sector, so it must not produce sector_done.
                        close_only       <= 1;
                        is_stop          <= 1;
                        restarting       <= 0;
                        poll_count       <= 0;
                        command_argument <= 0;
                        cmd_index        <= 0;
                        byte_tx          <= 8'h4c;
                        state            <= CMD_REQ;
                    end
                PRE_REQ:
                    if (!byte_busy) begin
                        byte_tx    <= 8'hff;
                        byte_start <= 1;
                        state      <= PRE_WAIT;
                    end
                PRE_WAIT:
                    if (byte_done) begin
                        byte_tx <= 8'h52;
                        state   <= CMD_REQ;
                    end
                CMD_REQ:
                    if (!byte_busy) begin
                        byte_start <= 1;
                        state      <= CMD_WAIT;
                    end
                CMD_WAIT:
                    if (byte_done) begin
                        if (cmd_index == 5) begin
                            poll_count <= 0;
                            state      <= is_stop ? STUFF_REQ : R1_REQ;
                        end else begin
                            cmd_index <= cmd_index + 1'b1;
                            byte_tx   <= command_byte(cmd_index + 1'b1);
                            state     <= CMD_REQ;
                        end
                    end
                STUFF_REQ:
                    if (!byte_busy) begin
                        byte_tx    <= 8'hff;
                        byte_start <= 1;
                        state      <= STUFF_WAIT;
                    end
                STUFF_WAIT:
                    if (byte_done) begin
                        poll_count <= 0;
                        state      <= R1_REQ;
                    end
                R1_REQ:
                    if (!byte_busy) begin
                        byte_tx    <= 8'hff;
                        byte_start <= 1;
                        state      <= R1_WAIT;
                    end
                R1_WAIT:
                    if (byte_done) begin
                        if (!byte_rx[7]) begin
                            last_r1    <= byte_rx;
                            poll_count <= 0;
                            if (byte_rx != 0) begin
                                if (is_stop)
                                    stop_failed;
                                else
                                    fail(8'h02);
                            end else if (is_stop)
                                state <= BUSY_REQ;
                            else begin
                                multi_active <= 1;
                                state        <= TOKEN_REQ;
                            end
                        end else if (poll_count == MAX_R1_BYTES - 1) begin
                            if (is_stop)
                                stop_failed;
                            else
                                fail(8'h01);
                        end else begin
                            poll_count <= poll_count + 1'b1;
                            state      <= R1_REQ;
                        end
                    end
                BUSY_REQ:
                    if (!byte_busy) begin
                        byte_tx    <= 8'hff;
                        byte_start <= 1;
                        state      <= BUSY_WAIT;
                    end
                BUSY_WAIT:
                    if (byte_done) begin
                        if (byte_rx == 8'hff) begin
                            multi_active <= 0;
                            state        <= POST_REQ;
                        end else if (poll_count == MAX_BUSY_BYTES - 1)
                            stop_failed;
                        else begin
                            poll_count <= poll_count + 1'b1;
                            state      <= BUSY_REQ;
                        end
                    end
                TOKEN_REQ:
                    if (!byte_busy) begin
                        byte_tx    <= 8'hff;
                        byte_start <= 1;
                        state      <= TOKEN_WAIT;
                    end
                TOKEN_WAIT:
                    if (byte_done) begin
                        if (byte_rx == 8'hfe) begin
                            data_count <= 0;
                            data_crc   <= 0;
                            state      <= DATA_REQ;
                        end else if (byte_rx != 8'hff)
                            fail(8'h04);
                        else if (poll_count == MAX_TOKEN_BYTES - 1)
                            fail(8'h03);
                        else begin
                            poll_count <= poll_count + 1'b1;
                            state      <= TOKEN_REQ;
                        end
                    end
                DATA_REQ:
                    if (!byte_busy) begin
                        byte_tx    <= 8'hff;
                        byte_start <= 1;
                        state      <= DATA_WAIT;
                    end
                DATA_WAIT:
                    if (byte_done) begin
                        sector_valid      <= 1;
                        sector_byte       <= byte_rx;
                        sector_byte_index <= data_count;
                        data_crc          <= crc16_byte(data_crc, byte_rx);
                        if (data_count == 511)
                            state <= CRC_H_REQ;
                        else begin
                            data_count <= data_count + 1'b1;
                            state      <= DATA_REQ;
                        end
                    end
                CRC_H_REQ:
                    if (!byte_busy) begin
                        byte_tx    <= 8'hff;
                        byte_start <= 1;
                        state      <= CRC_H_WAIT;
                    end
                CRC_H_WAIT:
                    if (byte_done) begin
                        crc_high <= byte_rx;
                        state    <= CRC_L_REQ;
                    end
                CRC_L_REQ:
                    if (!byte_busy) begin
                        byte_tx    <= 8'hff;
                        byte_start <= 1;
                        state      <= CRC_L_WAIT;
                    end
                CRC_L_WAIT:
                    if (byte_done) begin
                        if (CHECK_DATA_CRC && {crc_high, byte_rx} != data_crc)
                            fail(8'h05);
                        else begin
                            next_lba    <= held_lba + 1'b1;
                            sector_done <= 1;
                            state       <= IDLE;
                        end
                    end
                POST_REQ:
                    if (!byte_busy) begin
                        byte_tx    <= 8'hff;
                        byte_start <= 1;
                        state      <= POST_WAIT;
                    end
                POST_WAIT:
                    if (byte_done) begin
                        if (restarting) begin
                            restarting       <= 0;
                            is_stop          <= 0;
                            command_argument <= card_high_capacity ? held_lba : held_lba << 9;
                            cmd_index        <= 0;
                            state            <= PRE_REQ;
                        end else begin
                            sector_done <= !close_only;
                            close_only  <= 0;
                            state       <= IDLE;
                        end
                    end
                default: begin
                    sector_error <= 8'h0f;
                    multi_active <= 0;
                    state        <= IDLE;
                    sector_done  <= 1;
                end
            endcase
        end
    end
endmodule
