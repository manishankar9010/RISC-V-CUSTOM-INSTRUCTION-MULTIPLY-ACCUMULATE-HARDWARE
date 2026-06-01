`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.03.2026 13:44:21
// Design Name: 
// Module Name: if_id_register
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
//////////////////////////////////////////////////////////////////////////////////
module if_id_register (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,
    input  wire        flush,
    input  wire [31:0] if_pc,
    input  wire [31:0] if_instruction,
    output reg  [31:0] id_pc,
    output reg  [31:0] id_instruction
);
    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            id_pc          <= 32'h00000000;
            id_instruction <= 32'h00000013; // NOP
        end else if (!stall) begin
            id_pc          <= if_pc;
            id_instruction <= if_instruction;
        end
    end
endmodule
