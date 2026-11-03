// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：紧凑FAT32流读取器，按扇区跟踪文件偏移与簇链并输出错误原因。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps
// Bounded FAT32 walker with one cluster-to-LBA datapath. Native FAT32 uses
// 28-bit clusters; each supported media file is <32 MiB. Shared boot/video
// ownership supplies a stable directory throughout one file transaction.
module fat32_file_streamer_compact #(
    parameter integer MAX_VISITED_CLUSTERS = 65536
)(
    input wire        clk,
                      rst_n,
                      file_start,
    input wire [31:0] first_cluster,
                      file_size,
    input wire [7:0]  sectors_per_cluster,
    input wire [31:0] fat_start_lba,
                      data_start_lba,
                      max_cluster,
    output wire       file_busy,
    output reg        file_done,
                      file_valid,
    output reg [7:0]  file_byte,
    output reg [31:0] file_byte_offset,
    output reg [7:0]  fs_error,
    output reg        sector_req,
    output reg [31:0] sector_lba,
    input wire        sector_busy,
                      sector_valid,
    input wire [7:0]  sector_byte,
    input wire [8:0]  sector_byte_index,
    input wire        sector_done,
    input wire [7:0]  sector_error
);
    localparam IDLE = 0, ADDR = 1, REQ = 2, DATA = 3, FAT = 4, CHECK = 5, FINISH = 6, SCALE = 7;
    reg [2:0] state;
    reg fat_access;
    reg [27:0] cluster, checkpoint;
    reg [27:0] fat_value;
    reg [24:0] remaining, position;
    reg [6:0] sector_number;
    reg [31:0] scaled;
    localparam CW = $clog2(MAX_VISITED_CLUSTERS + 1);
    reg [CW - 1:0] visited, power, span;
    wire [8:0] entry_offset = {cluster[6:0], 2'b00};
    wire valid_spc =
             sectors_per_cluster != 0 && (sectors_per_cluster & (sectors_per_cluster - 1'b1)) == 0;
    wire [31:0] address_a = fat_access ? fat_start_lba : data_start_lba;
    wire [31:0] address_b = fat_access ? {11'd0, cluster[27:7]} : scaled;
    assign file_busy        = state != IDLE;
    task fail;
        input [7:0] code;
        begin
            fs_error <= code;
            state    <= FINISH;
        end
    endtask
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            state            <= IDLE;
            fat_access       <= 0;
            cluster          <= 0;
            checkpoint       <= 0;
            fat_value        <= 0;
            remaining        <= 0;
            position         <= 0;
            sector_number    <= 0;
            scaled           <= 0;
            visited          <= 0;
            power            <= 1;
            span             <= 0;
            file_done        <= 0;
            file_valid       <= 0;
            file_byte        <= 0;
            file_byte_offset <= 0;
            fs_error         <= 0;
            sector_req       <= 0;
            sector_lba       <= 0;
        end else begin
            file_done  <= 0;
            file_valid <= 0;
            sector_req <= 0;
            if (state == DATA && sector_valid && remaining != 0) begin
                file_valid       <= 1;
                file_byte        <= sector_byte;
                file_byte_offset <= {7'd0, position};
                position         <= position + 1'b1;
                remaining        <= remaining - 1'b1;
            end
            if (state == FAT && sector_valid)
                case (sector_byte_index - entry_offset)
                    0:
                        fat_value[7:0] <= sector_byte;
                    1:
                        fat_value[15:8] <= sector_byte;
                    2:
                        fat_value[23:16] <= sector_byte;
                    3:
                        fat_value[27:24] <= sector_byte[3:0];
                endcase
            case (state)
                IDLE:
                    if (file_start) begin
                        fs_error         <= 0;
                        file_byte_offset <= 0;
                        remaining        <= file_size[24:0];
                        position         <= 0;
                        sector_number    <= 0;
                        cluster          <= first_cluster[27:0];
                        checkpoint       <= first_cluster[27:0];
                        visited          <= 1;
                        power            <= 1;
                        span             <= 0;
                        fat_access       <= 0;
                        if (|file_size[31:25])
                            fail(8'h27);
                        else if (file_size == 0)
                            state <= FINISH;
                        else if (|first_cluster[31:28])
                            fail(8'he1);
                        else if (first_cluster < 2)
                            fail(8'he2);
                        else if (first_cluster > max_cluster)
                            fail(8'he3);
                        else if (!valid_spc)
                            fail(8'he4);
                        else
                            state <= SCALE;
                    end
                SCALE: begin
                    scaled <= ({4'd0, cluster} - 32'd2) * sectors_per_cluster;
                    state  <= ADDR;
                end
                ADDR: begin
                    sector_lba <= address_a + address_b;
                    state      <= REQ;
                end
                REQ:
                    if (!sector_busy) begin
                        sector_req <= 1;
                        state      <= fat_access ? FAT : DATA;
                    end
                DATA:
                    if (sector_done) begin
                        if (sector_error != 0)
                            fail(8'h10);
                        else if (remaining == 0 || (remaining == 1 && sector_valid))
                            state <= FINISH;
                        else if ({1'b0, sector_number} + 8'd1 < sectors_per_cluster) begin
                            sector_number <= sector_number + 1'b1;
                            sector_lba    <= sector_lba + 1'b1;
                            state         <= REQ;
                        end else begin
                            sector_number <= 0;
                            fat_access    <= 1;
                            fat_value     <= 0;
                            state         <= ADDR;
                        end
                    end
                FAT:
                    if (sector_done) begin
                        if (sector_error != 0)
                            fail(8'h10);
                        else
                            state <= CHECK;
                    end
                CHECK: begin
                    if (fat_value >= 28'hffffff8)
                        fail(8'h25);
                    else if (fat_value == 28'hffffff7)
                        fail(8'he7);
                    else if (fat_value < 2)
                        fail(8'he5);
                    else if ({4'd0, fat_value} > max_cluster)
                        fail(8'he6);
                    else if (visited >= MAX_VISITED_CLUSTERS)
                        fail(8'h26);
                    else if (fat_value == checkpoint)
                        fail(8'h23);
                    else begin
                        if (span + 1'b1 == power) begin
                            checkpoint <= fat_value;
                            power      <= power << 1;
                            span       <= 0;
                        end else
                            span <= span + 1'b1;
                        cluster    <= fat_value;
                        visited    <= visited + 1'b1;
                        fat_access <= 0;
                        state      <= SCALE;
                    end
                end
                FINISH: begin
                    file_done <= 1;
                    state     <= IDLE;
                end
                default:
                    state <= IDLE;
            endcase
        end
endmodule
