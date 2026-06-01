`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.03.2026 13:56:37
// Design Name: 
// Module Name: immediate_generator
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
module immediate_generator (
    input  wire [31:0] instruction,
    input  wire [6:0]  opcode,
    output reg  [31:0] immediate
);
    always @(*) begin
        case (opcode)
            7'b0010011, // I-type ALU
            7'b0000011, // Load
            7'b1100111: // JALR
                immediate = {{20{instruction[31]}}, instruction[31:20]};

            7'b0100011: // Store
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

            7'b1100011: // Branch
                immediate = {{19{instruction[31]}}, instruction[31], instruction[7],
                             instruction[30:25], instruction[11:8], 1'b0};

            7'b0110111, // LUI
            7'b0010111: // AUIPC
                immediate = {instruction[31:12], 12'b0};

            7'b1101111: // JAL
                immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                             instruction[20], instruction[30:21], 1'b0};

            default: immediate = 32'h00000000;
        endcase
    end
endmodule
