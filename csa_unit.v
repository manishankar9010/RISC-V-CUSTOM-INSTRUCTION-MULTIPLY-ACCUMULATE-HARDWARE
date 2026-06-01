`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.03.2026 09:53:10
// Design Name: 
// Module Name: csa_unit
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
module csa_unit (
    input  [31:0] in1,
    input  [31:0] in2,
    input  [31:0] in3,
    output [31:0] sum,
    output [31:0] carry
);
    assign sum   = in1 ^ in2 ^ in3;
    assign carry = ((in1 & in2) | (in2 & in3) | (in1 & in3)) << 1;
endmodule
