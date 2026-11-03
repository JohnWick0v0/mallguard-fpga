// ============================================================================
// 工程：mall_emergency_multimedia_display / 商安视界 / HX4S20C / EG4S20
// 职责：识别FAT32卷并扫描根目录，查找所选时段图片、音乐及共享媒体。
// 时钟：clk。
// 复位：rst_n（低有效异步复位）。
// 维护：握手、寄存器/实例标识和流水拍数均来自用户验证的最终版。
//       涉及跨域、HS/VS/DE/X或SPI事务时，须同步检查对应仿真及top.sdc。
// 来源映射：docs/naming_map.json（包含原文件SHA-256）。
// ============================================================================
`timescale 1ns / 1ps

module fat32_volume_scanner #(
    parameter integer SUPPORT_SLOTS    = 0,
    parameter integer AUDIO_SCAN     = 0,
    parameter integer SCAN_EMERGENCY = 0
)(
    output reg         video_valid,
    output reg [31:0]  video_cluster,
                       video_size,
    input wire [1:0]   selected_slot,
    input wire         clk,
    input wire         rst_n,
    input wire         scan_start,
    output wire        scan_busy,
    output reg         scan_done,
    output reg [7:0]   fs_error,
    output reg [31:0]  partition_lba,
    output reg [7:0]   sectors_per_cluster,
    output reg [31:0]  fat_start_lba,
    output reg [31:0]  data_start_lba,
    output reg [31:0]  max_cluster,
    output reg         lost_valid,
    output reg [31:0]  lost_cluster,
                       lost_size,
    output reg         alarm_valid,
    output reg [31:0]  alarm_cluster,
                       alarm_size,
    output reg [2:0]   extra_valid,
    output wire [95:0] extra_clusters,
                       extra_sizes,
    output reg         fire_valid,
    output reg [31:0]  fire_cluster,
                       fire_size,
    output reg         audio_valid,
    output reg [31:0]  audio_cluster,
                       audio_size,
    output reg [3:0]   resource_valid,
    output reg [31:0]  resource0_cluster,
    output reg [31:0]  resource1_cluster,
    output reg [31:0]  resource2_cluster,
    output reg [31:0]  resource3_cluster,
    output reg [31:0]  resource0_size,
    output reg [31:0]  resource1_size,
    output reg [31:0]  resource2_size,
    output reg [31:0]  resource3_size,
    output reg         sector_req,
    output reg [31:0]  sector_lba,
    input wire         sector_busy,
    input wire         sector_valid,
    input wire [7:0]   sector_byte,
    input wire [8:0]   sector_byte_index,
    input wire         sector_done,
    input wire [7:0]   sector_error
);

    localparam ERR_NONE             = 8'h00;
    localparam ERR_SECTOR           = 8'h10;
    localparam ERR_BOOT_SIGNATURE   = 8'h20;
    localparam ERR_UNSUPPORTED_BPB  = 8'h21;
    localparam ERR_RESOURCE_MISSING = 8'h22;

    localparam ST_DIR_LAST    = 4'd12;
    localparam ST_DIR_LOAD    = 4'd13;
    localparam ST_IDLE        = 4'd0;
    localparam ST_READ0_REQ   = 4'd1;
    localparam ST_READ0_WAIT  = 4'd2;
    localparam ST_BOOT_PARSE  = 4'd3;
    localparam ST_BOOT_REQ    = 4'd4;
    localparam ST_BOOT_WAIT   = 4'd5;
    localparam ST_ROOT_REQ    = 4'd6;
    localparam ST_ROOT_WAIT   = 4'd7;
    localparam ST_DIR_SCAN    = 4'd8;
    localparam ST_FINISH      = 4'd9;
    localparam ST_BOOT_LAYOUT = 4'd10;
    localparam ST_BOOT_ROOT   = 4'd11;

    reg [83:0] extra_cluster_storage;
    reg [65:0] extra_size_storage;
    assign extra_clusters = {4'd0,
               extra_cluster_storage[83:56],
               4'd0,
               extra_cluster_storage[55:28],
               4'd0,
               extra_cluster_storage[27:0]};
    assign extra_sizes    = {10'd0,
               extra_size_storage[65:44],
               10'd0,
               extra_size_storage[43:22],
               10'd0,
               extra_size_storage[21:0]};
    reg [3:0] state;
    reg [7:0] sector_buffer[0:511];
    reg [4:0] directory_entry_index;
    // Root sectors have a single synchronous RAM read port. Decode one
    // 32-byte entry at a time rather than selecting 20+ bytes in parallel
    // from a 512-byte register array.
    reg [7:0] directory_ram[0:511] /* fehdl force_ram=1, ram_style="bram" */;
    reg [7:0] entry_buffer[0:31];
    reg [7:0] directory_read_byte;
    reg [5:0] directory_byte_index;
    wire [8:0] directory_read_address = {
                     directory_entry_index[3:0], directory_byte_index[4:0]};
    always @(posedge clk) begin
        if (sector_valid && state == ST_ROOT_WAIT)
            directory_ram[sector_byte_index] <= sector_byte;
        directory_read_byte <= directory_ram[directory_read_address];
    end
    reg [31:0] root_cluster;
    reg [31:0] total_sectors;
    reg [31:0] fat_sectors;
    reg [7:0] fat_count;
    reg [15:0] reserved_sectors;
    reg [31:0] root_lba;
    reg [31:0] data_sector_count;
    reg [31:0] fat_span;
    reg [2:0] sectors_per_cluster_shift;
    reg [6:0] root_sector_index;

    assign scan_busy = (state != ST_IDLE);

    function [15:0] le16;
        input integer offset;
        begin
            le16 = {sector_buffer[offset + 1], sector_buffer[offset]};
        end
    endfunction

    function [31:0] le32;
        input integer offset;
        begin
            le32 = {sector_buffer[offset + 3],
                sector_buffer[offset + 2],
                sector_buffer[offset + 1],
                sector_buffer[offset]};
        end
    endfunction

    function valid_spc;
        input [7:0] value;
        begin
            valid_spc = value != 0 && ((value & (value - 1'b1)) == 0);
        end
    endfunction

    function [2:0] spc_shift;
        input [7:0] value;
        begin
            case (value)
                8'd2:
                    spc_shift = 3'd1;
                8'd4:
                    spc_shift = 3'd2;
                8'd8:
                    spc_shift = 3'd3;
                8'd16:
                    spc_shift = 3'd4;
                8'd32:
                    spc_shift = 3'd5;
                8'd64:
                    spc_shift = 3'd6;
                8'd128:
                    spc_shift = 3'd7;
                default:
                    spc_shift = 3'd0;
            endcase
        end
    endfunction

    // All groups use exactly three prefix letters and one digit (8.3 names).
    wire [1:0] slot        = SUPPORT_SLOTS ? selected_slot : 2'd0;
    wire [23:0] ad_prefix  = slot == 0 ? "PIC" : slot == 1 ? "MOR" : slot == 2 ? "DAY" : "EVE";
    wire [87:0] song_name  = slot == 0   ? "MUSIC   WAV"
                               : slot == 1 ? "MORN    WAV"
                               : slot == 2 ? "NOON    WAV"
                                           : "EVEN    WAV";
    wire [87:0] entry_name = {entry_buffer[0],
                      entry_buffer[1],
                      entry_buffer[2],
                      entry_buffer[3],
                      entry_buffer[4],
                      entry_buffer[5],
                      entry_buffer[6],
                      entry_buffer[7],
                      entry_buffer[8],
                      entry_buffer[9],
                      entry_buffer[10]};
    wire ordinary_file       = entry_buffer[0] != 8'he5 && (entry_buffer[11] & 8'h18) == 0;
    wire picture_match       = ordinary_file && entry_name[87:64] == ad_prefix &&
                               entry_buffer[3] >= "1" && entry_buffer[3] <= "4" &&
                               entry_name[55:0] == "    BMP";
    wire song_match          = ordinary_file && entry_name == song_name;
    function [1:0] matching_resource;
        input integer base;
        begin
            matching_resource = entry_buffer[base + 3] - 8'h31;
        end
    endfunction

    task finish_with_error;
        input [7:0] code;
        begin
            fs_error <= code;
            state    <= ST_FINISH;
        end
    endtask

    task accept_directory_entry;
        input integer base;
        reg [1:0] resource_index;
        reg [31:0] first_cluster;
        reg [31:0] file_size;
        begin
            resource_index = AUDIO_SCAN ? 2'd0 : matching_resource(base);
            first_cluster  = {entry_buffer[base + 21],
                entry_buffer[base + 20],
                entry_buffer[base + 27],
                entry_buffer[base + 26]};
            file_size = {entry_buffer[31], entry_buffer[30], entry_buffer[29], entry_buffer[28]};
            case (resource_index)
                2'd0: begin
                    resource0_cluster <= first_cluster;
                    resource0_size    <= file_size;
                    resource_valid[0] <= 1'b1;
                end
                2'd1: begin
                    resource1_cluster <= first_cluster;
                    resource1_size    <= file_size;
                    resource_valid[1] <= 1'b1;
                end
                2'd2: begin
                    resource2_cluster <= first_cluster;
                    resource2_size    <= file_size;
                    resource_valid[2] <= 1'b1;
                end
                default: begin
                    resource3_cluster <= first_cluster;
                    resource3_size    <= file_size;
                    resource_valid[3] <= 1'b1;
                end
            endcase
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                     <= ST_IDLE;
            scan_done                 <= 1'b0;
            fs_error                  <= ERR_NONE;
            partition_lba             <= 32'd0;
            sectors_per_cluster       <= 8'd0;
            fat_start_lba             <= 32'd0;
            data_start_lba            <= 32'd0;
            max_cluster               <= 32'd0;
            resource_valid            <= 4'd0;
            video_valid               <= 0;
            video_cluster             <= 0;
            video_size                <= 0;
            audio_valid               <= 0;
            audio_cluster             <= 0;
            audio_size                <= 0;
            lost_valid                <= 0;
            lost_cluster              <= 0;
            lost_size                 <= 0;
            alarm_valid               <= 0;
            alarm_cluster             <= 0;
            alarm_size                <= 0;
            fire_valid                <= 0;
            fire_cluster              <= 0;
            fire_size                 <= 0;
            extra_valid               <= 0;
            extra_cluster_storage     <= 0;
            extra_size_storage        <= 0;
            resource0_cluster         <= 32'd0;
            resource1_cluster         <= 32'd0;
            resource2_cluster         <= 32'd0;
            resource3_cluster         <= 32'd0;
            resource0_size            <= 32'd0;
            resource1_size            <= 32'd0;
            resource2_size            <= 32'd0;
            resource3_size            <= 32'd0;
            sector_req                <= 1'b0;
            sector_lba                <= 32'd0;
            directory_entry_index     <= 5'd0;
            directory_byte_index      <= 6'd0;
            root_cluster              <= 32'd0;
            total_sectors             <= 32'd0;
            fat_sectors               <= 32'd0;
            fat_count                 <= 8'd0;
            reserved_sectors          <= 16'd0;
            root_lba                  <= 32'd0;
            data_sector_count         <= 32'd0;
            fat_span                  <= 32'd0;
            sectors_per_cluster_shift <= 3'd0;
            root_sector_index         <= 7'd0;
        end else begin
            scan_done  <= 1'b0;
            sector_req <= 1'b0;
            if (sector_valid && state != ST_ROOT_WAIT)
                sector_buffer[sector_byte_index] <= sector_byte;

            case (state)
                ST_IDLE:
                    if (scan_start) begin
                        fs_error              <= ERR_NONE;
                        partition_lba         <= 32'd0;
                        resource_valid        <= 4'd0;
                        video_valid           <= 0;
                        video_cluster         <= 0;
                        video_size            <= 0;
                        audio_valid           <= 0;
                        audio_cluster         <= 0;
                        audio_size            <= 0;
                        lost_valid            <= 0;
                        lost_cluster          <= 0;
                        lost_size             <= 0;
                        alarm_valid           <= 0;
                        alarm_cluster         <= 0;
                        alarm_size            <= 0;
                        fire_valid            <= 0;
                        fire_cluster          <= 0;
                        fire_size             <= 0;
                        extra_valid           <= 0;
                        extra_cluster_storage <= 0;
                        extra_size_storage    <= 0;
                        state                 <= ST_READ0_REQ;
                    end
                ST_READ0_REQ:
                    if (!sector_busy) begin
                        sector_lba <= 32'd0;
                        sector_req <= 1'b1;
                        state      <= ST_READ0_WAIT;
                    end
                ST_READ0_WAIT:
                    if (sector_done) begin
                        if (sector_error != 0)
                            finish_with_error(ERR_SECTOR);
                        else if (sector_buffer[510] != 8'h55 || sector_buffer[511] != 8'haa)
                            finish_with_error(ERR_BOOT_SIGNATURE);
                        else if (sector_buffer[0] == 8'heb || sector_buffer[0] == 8'he9) begin
                            partition_lba <= 32'd0;
                            state         <= ST_BOOT_PARSE;
                        end else if (sector_buffer[450] == 8'h0b || sector_buffer[450] == 8'h0c)
                        begin
                            partition_lba <= le32(454);
                            sector_lba    <= le32(454);
                            state         <= ST_BOOT_REQ;
                        end else begin
                            finish_with_error(ERR_UNSUPPORTED_BPB);
                        end
                    end
                ST_BOOT_REQ:
                    if (!sector_busy) begin
                        sector_req <= 1'b1;
                        state      <= ST_BOOT_WAIT;
                    end
                ST_BOOT_WAIT:
                    if (sector_done) begin
                        if (sector_error != 0)
                            finish_with_error(ERR_SECTOR);
                        else if (sector_buffer[510] != 8'h55 || sector_buffer[511] != 8'haa)
                            finish_with_error(ERR_BOOT_SIGNATURE);
                        else
                            state <= ST_BOOT_PARSE;
                    end
                ST_BOOT_PARSE: begin
                    if (le16(11) != 16'd512 || !valid_spc(sector_buffer[13]) || le16(14) == 0 ||
                        (sector_buffer[16] != 1 && sector_buffer[16] != 2) || le16(17) != 0 ||
                        le16(22) != 0 || le32(32) == 0 || le32(36) == 0 || le32(44) < 2) begin
                        finish_with_error(ERR_UNSUPPORTED_BPB);
                    end else begin
                        sectors_per_cluster       <= sector_buffer[13];
                        reserved_sectors          <= le16(14);
                        fat_count                 <= sector_buffer[16];
                        total_sectors             <= le32(32);
                        fat_sectors               <= le32(36);
                        root_cluster              <= le32(44);
                        sectors_per_cluster_shift <= spc_shift(sector_buffer[13]);
                        fat_span      <= sector_buffer[16] == 2 ? (le32(36) << 1) : le32(36);
                        fat_start_lba <= partition_lba + le16(14);
                        state         <= ST_BOOT_LAYOUT;
                    end
                end
                ST_BOOT_LAYOUT: begin
                    data_start_lba    <= partition_lba + reserved_sectors + fat_span;
                    data_sector_count <= total_sectors - reserved_sectors - fat_span;
                    state             <= ST_BOOT_ROOT;
                end
                ST_BOOT_ROOT: begin
                    root_sector_index <= 7'd0;
                    max_cluster       <= (data_sector_count >> sectors_per_cluster_shift) + 1'b1;
                    root_lba <= data_start_lba + ((root_cluster - 2) << sectors_per_cluster_shift);
                    sector_lba <=
                        data_start_lba + ((root_cluster - 2) << sectors_per_cluster_shift);
                    state <= ST_ROOT_REQ;
                end
                ST_ROOT_REQ:
                    if (!sector_busy) begin
                        sector_req <= 1'b1;
                        state      <= ST_ROOT_WAIT;
                    end
                ST_ROOT_WAIT:
                    if (sector_done) begin
                        if (sector_error != 0)
                            finish_with_error(ERR_SECTOR);
                        else begin
                            directory_entry_index <= 5'd0;
                            directory_byte_index  <= 0;
                            state                 <= ST_DIR_LOAD;
                        end
                    end
                ST_DIR_LOAD: begin
                    if (directory_byte_index != 0)
                        entry_buffer[directory_byte_index - 1'b1] <= directory_read_byte;
                    if (directory_byte_index == 6'd32)
                        state <= ST_DIR_SCAN;
                    else
                        directory_byte_index <= directory_byte_index + 1'b1;
                end
                ST_DIR_SCAN: begin
                    if (entry_buffer[0] != 8'he5 && (entry_buffer[11] & 8'h18) == 0 &&
                        {entry_buffer[0],
                            entry_buffer[1],
                            entry_buffer[2],
                            entry_buffer[3],
                            entry_buffer[4],
                            entry_buffer[5],
                            entry_buffer[6],
                            entry_buffer[7],
                            entry_buffer[8],
                            entry_buffer[9],
                            entry_buffer[10]} == "VIDEO   BIN") begin
                        video_valid   <= 1;
                        video_cluster <= {
                            entry_buffer[21], entry_buffer[20], entry_buffer[27], entry_buffer[26]};
                        video_size <= {
                            entry_buffer[31], entry_buffer[30], entry_buffer[29], entry_buffer[28]};
                    end

                    if (SCAN_EMERGENCY && entry_buffer[0] != 8'he5 &&
                        (entry_buffer[11] & 8'h18) == 0) begin
                        case ({entry_buffer[0],
                            entry_buffer[1],
                            entry_buffer[2],
                            entry_buffer[3],
                            entry_buffer[4],
                            entry_buffer[5],
                            entry_buffer[6],
                            entry_buffer[7],
                            entry_buffer[8],
                            entry_buffer[9],
                            entry_buffer[10]})
                            "POWER   BMP": begin
                                extra_valid[0] <=
                                    entry_buffer[31] == 0 && entry_buffer[30][7:6] == 0;
                                extra_cluster_storage[27:0] <= {entry_buffer[21][3:0],
                                    entry_buffer[20],
                                    entry_buffer[27],
                                    entry_buffer[26]};
                                extra_size_storage[21:0] <=
                                    {entry_buffer[30][5:0], entry_buffer[29], entry_buffer[28]};
                            end
                            "SECURITYBMP": begin
                                extra_valid[1] <=
                                    entry_buffer[31] == 0 && entry_buffer[30][7:6] == 0;
                                extra_cluster_storage[55:28] <= {entry_buffer[21][3:0],
                                    entry_buffer[20],
                                    entry_buffer[27],
                                    entry_buffer[26]};
                                extra_size_storage[43:22] <=
                                    {entry_buffer[30][5:0], entry_buffer[29], entry_buffer[28]};
                            end
                            "MEDICAL BMP": begin
                                extra_valid[2] <=
                                    entry_buffer[31] == 0 && entry_buffer[30][7:6] == 0;
                                extra_cluster_storage[83:56] <= {entry_buffer[21][3:0],
                                    entry_buffer[20],
                                    entry_buffer[27],
                                    entry_buffer[26]};
                                extra_size_storage[65:44] <=
                                    {entry_buffer[30][5:0], entry_buffer[29], entry_buffer[28]};
                            end
                        endcase
                    end
                    if (entry_buffer[0] != 8'he5 && (entry_buffer[11] & 8'h18) == 0 &&
                        {entry_buffer[0],
                            entry_buffer[1],
                            entry_buffer[2],
                            entry_buffer[3],
                            entry_buffer[4],
                            entry_buffer[5],
                            entry_buffer[6],
                            entry_buffer[7],
                            entry_buffer[8],
                            entry_buffer[9],
                            entry_buffer[10]} == "LOST    WAV") begin
                        lost_valid   <= 1;
                        lost_cluster <= {
                            entry_buffer[21], entry_buffer[20], entry_buffer[27], entry_buffer[26]};
                        lost_size <= {
                            entry_buffer[31], entry_buffer[30], entry_buffer[29], entry_buffer[28]};
                    end
                    if (entry_buffer[0] != 8'he5 && (entry_buffer[11] & 8'h18) == 0 &&
                        {entry_buffer[0],
                            entry_buffer[1],
                            entry_buffer[2],
                            entry_buffer[3],
                            entry_buffer[4],
                            entry_buffer[5],
                            entry_buffer[6],
                            entry_buffer[7],
                            entry_buffer[8],
                            entry_buffer[9],
                            entry_buffer[10]} == "ALARM   WAV") begin
                        alarm_valid   <= 1;
                        alarm_cluster <= {
                            entry_buffer[21], entry_buffer[20], entry_buffer[27], entry_buffer[26]};
                        alarm_size <= {
                            entry_buffer[31], entry_buffer[30], entry_buffer[29], entry_buffer[28]};
                    end

                    if (entry_buffer[0] != 8'he5 && (entry_buffer[11] & 8'h18) == 0 &&
                        {entry_buffer[0],
                            entry_buffer[1],
                            entry_buffer[2],
                            entry_buffer[3],
                            entry_buffer[4],
                            entry_buffer[5],
                            entry_buffer[6],
                            entry_buffer[7],
                            entry_buffer[8],
                            entry_buffer[9],
                            entry_buffer[10]} == "FIRE    BMP") begin
                        fire_valid   <= 1;
                        fire_cluster <= {
                            entry_buffer[21], entry_buffer[20], entry_buffer[27], entry_buffer[26]};
                        fire_size <= {
                            entry_buffer[31], entry_buffer[30], entry_buffer[29], entry_buffer[28]};
                    end
                    if (entry_buffer[0] != 8'he5 && (entry_buffer[11] & 8'h18) == 0 &&
                        {entry_buffer[0],
                            entry_buffer[1],
                            entry_buffer[2],
                            entry_buffer[3],
                            entry_buffer[4],
                            entry_buffer[5],
                            entry_buffer[6],
                            entry_buffer[7],
                            entry_buffer[8],
                            entry_buffer[9],
                            entry_buffer[10]} == song_name) begin
                        audio_valid   <= 1;
                        audio_cluster <= {
                            entry_buffer[21], entry_buffer[20], entry_buffer[27], entry_buffer[26]};
                        audio_size <= {
                            entry_buffer[31], entry_buffer[30], entry_buffer[29], entry_buffer[28]};
                    end
                    if (entry_buffer[0] == 8'h00) begin
                        if ((AUDIO_SCAN ? resource_valid[0] : resource_valid == 4'hf))
                            state <= ST_FINISH;
                        else
                            finish_with_error(ERR_RESOURCE_MISSING);
                    end else begin
                        if (AUDIO_SCAN ? song_match : picture_match)
                            accept_directory_entry(0);

                        if (directory_entry_index == 5'd15) begin
                            state <= ST_DIR_LAST;
                        end else begin
                            directory_entry_index <= directory_entry_index + 1'b1;
                            directory_byte_index  <= 0;
                            state                 <= ST_DIR_LOAD;
                        end
                    end
                end
                ST_DIR_LAST: begin
                    if (AUDIO_SCAN && resource_valid[0])
                        state <= ST_FINISH;
                    else if (({1'b0, root_sector_index} + 1'b1) <
                             (8'd1 << sectors_per_cluster_shift)) begin
                        root_sector_index <= root_sector_index + 1'b1;
                        sector_lba        <= root_lba + {25'd0, root_sector_index} + 1'b1;
                        state             <= ST_ROOT_REQ;
                    end else if (resource_valid == 4'hf)
                        state <= ST_FINISH;
                    else
                        finish_with_error(ERR_RESOURCE_MISSING);
                end
                ST_FINISH: begin
                    scan_done <= 1'b1;
                    state     <= ST_IDLE;
                end
                default:
                    state <= ST_IDLE;
            endcase
        end
    end
endmodule
