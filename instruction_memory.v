`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.03.2026 13:43:36
// Design Name: 
// Module Name: instruction_memory
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
// SYNTHESIS FIX (duplicate timescale removed - was lines 1 and 21)
//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
// Module Name: instruction_memory
// Description: Instruction ROM - 256 words (1KB)
//
// SYNTHESIS FIX:
//   The original file filled ALL locations with NOPs in the initial block.
//   Vivado synthesized this as a constant-output ROM, so the synthesizer
//   constant-folded mac_enable / mul_enable to 0 and trimmed the entire
//   MAC / MUL / ALU datapath, leaving only the PC.
//
//   Fix: Pre-load the test program (ADDI, R-type, MUL, MAC x3) directly in
//   the initial block.  Vivado synthesises the initial block as a ROM with
//   these exact values, so all control signals toggle during synthesis and
//   the full datapath is preserved.
//
//   The testbench can still override memory[] at #1 in simulation - that
//   has no effect on synthesis and the two flows stay independent.
// ============================================================================
module instruction_memory (
    input  wire [31:0] address,
    output wire [31:0] instruction
);
    reg [31:0] memory [0:255];
    integer i;

    initial begin
        // Step 1: Fill everything with NOP
        for (i = 0; i < 256; i = i + 1)
            memory[i] = 32'h00000013;   // NOP  (ADDI x0, x0, 0)

        // Step 2: Real test program
        // Group 1 - Immediate
        memory[ 0] = 32'h00500093;  // ADDI  x1,  x0, 5
        memory[ 1] = 32'h00300113;  // ADDI  x2,  x0, 3

        // NOP gap (pipeline fill)
        memory[ 2] = 32'h00000013;

        // Group 2 - R-Type Arithmetic
        memory[ 3] = 32'h002081B3;  // ADD   x3,  x1, x2   -> 8
        memory[ 4] = 32'h40208233;  // SUB   x4,  x1, x2   -> 2
        memory[ 5] = 32'h0020F2B3;  // AND   x5,  x1, x2   -> 1
        memory[ 6] = 32'h0020E333;  // OR    x6,  x1, x2   -> 7
        memory[ 7] = 32'h0020C3B3;  // XOR   x7,  x1, x2   -> 6

        // Group 3 - Shift & Compare
        memory[ 8] = 32'h00209413;  // SLLI  x8,  x1, 2    -> 20
        memory[ 9] = 32'h0011D493;  // SRLI  x9,  x3, 1    -> 4
        memory[10] = 32'h00122533;  // SLT   x10, x4, x1   -> 1

        // Group 4 - Load / Store
        memory[11] = 32'h00102023;  // SW    x1,  0(x0)
        memory[12] = 32'h00002583;  // LW    x11, 0(x0)    -> 5

        // Group 5 - MUL (M-Extension)
        memory[13] = 32'h02208633;  // MUL   x12, x1, x2   -> 15

        // Pipeline drain before MAC
        memory[14] = 32'h00000013;
        memory[15] = 32'h00000013;
        memory[16] = 32'h00000013;

        // Group 6 - MAC x3  (opcode=0001011, funct3=000, funct7=0000001)
        // rd <- old accumulator;  accumulator <- accumulator + (A[15:0] x B[15:0])
        memory[17] = 32'h0220868B;  // MAC   x13, x1, x2   rd=0,  accum->15
        memory[18] = 32'h00000013;
        memory[19] = 32'h00000013;
        memory[20] = 32'h00000013;
        memory[21] = 32'h00000013;
        memory[22] = 32'h0220870B;  // MAC   x14, x1, x2   rd=15, accum->30
        memory[23] = 32'h00000013;
        memory[24] = 32'h00000013;
        memory[25] = 32'h00000013;
        memory[26] = 32'h00000013;
        memory[27] = 32'h0220878B;  // MAC   x15, x1, x2   rd=30, accum->45
        memory[28] = 32'h00000013;
        memory[29] = 32'h00000013;
        memory[30] = 32'h00000013;
        memory[31] = 32'h00000013;
        // memory[32..255] remain NOP
    end

    // Word-addressed: byte address -> word index
    assign instruction = memory[address[9:2]];

endmodule