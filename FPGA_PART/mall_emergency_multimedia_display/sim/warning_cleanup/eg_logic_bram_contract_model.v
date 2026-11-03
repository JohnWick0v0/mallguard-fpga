`timescale 1ns / 1ps
// Verification-only model of the documented equal-width SP/DP interface.
// It checks wrapper wiring and synchronous read latency. It does not replace
// TD's vendor implementation or certify analog hardware timing.
module EG_LOGIC_BRAM #(
    parameter DATA_WIDTH_A = 6, DATA_WIDTH_B = 6,
    parameter ADDR_WIDTH_A = 6, ADDR_WIDTH_B = 6,
    parameter DATA_DEPTH_A = 64, DATA_DEPTH_B = 64,
    parameter MODE = "DP", REGMODE_A = "NOREG", REGMODE_B = "NOREG",
    parameter WRITEMODE_A = "NORMAL", WRITEMODE_B = "NORMAL",
    parameter BYTE_ENABLE = 0, BYTE_A = 1, BYTE_B = 1,
    parameter INIT_FILE = "NONE", IMPLEMENT = "9K"
) (
    output reg [DATA_WIDTH_A-1:0] doa,
    output reg [DATA_WIDTH_B-1:0] dob,
    input wire [DATA_WIDTH_A-1:0] dia,
    input wire [DATA_WIDTH_B-1:0] dib,
    input wire cea, ocea, clka, wea, rsta,
    input wire ceb, oceb, clkb, web, rstb,
    input wire bea, beb,
    input wire [ADDR_WIDTH_A-1:0] addra,
    input wire [ADDR_WIDTH_B-1:0] addrb
);
    reg [DATA_WIDTH_A-1:0] memory [0:DATA_DEPTH_A-1];
    initial begin
        if (DATA_WIDTH_A != DATA_WIDTH_B || DATA_DEPTH_A != DATA_DEPTH_B ||
            REGMODE_A != "NOREG" || REGMODE_B != "NOREG" ||
            (BYTE_ENABLE != 0 && !(BYTE_ENABLE == 8 && DATA_WIDTH_A == 8 && BYTE_A == 1 && BYTE_B == 1)) ||
            (MODE != "SP" && MODE != "DP"))
            $fatal(1, "Unsupported memory configuration in contract test");
        if (INIT_FILE != "NONE")
            $readmemh(INIT_FILE, memory);
    end
    always @(posedge clka) begin
        if (bea !== 1'b1 || beb !== 1'b1 || rsta !== 1'b0 || rstb !== 1'b0)
            $fatal(1, "Memory wrapper has an unconnected control pin");
        if (cea) begin
            if (wea) memory[addra] <= dia;
            else doa <= memory[addra];
        end
    end
    always @(posedge clkb) begin
        if (ceb) begin
            if (web) memory[addrb] <= dib;
            else dob <= memory[addrb];
        end
    end
endmodule
