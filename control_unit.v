`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.03.2026 13:45:56
// Design Name: 
// Module Name: control_unit
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
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,
    output reg        mem_to_reg,
    output reg        mem_read,
    output reg        mem_write,
    output reg        alu_src,
    output reg  [3:0] alu_op,
    output reg        branch,
    output reg        jump,
    output reg        mul_enable,
    output reg        div_enable,
    output reg        mac_enable
);
    // ALU op codes
    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_AND  = 4'd2;
    localparam ALU_OR   = 4'd3;
    localparam ALU_XOR  = 4'd4;
    localparam ALU_SLL  = 4'd5;
    localparam ALU_SRL  = 4'd6;
    localparam ALU_SRA  = 4'd7;
    localparam ALU_SLT  = 4'd8;
    localparam ALU_SLTU = 4'd9;
 
    // Custom MAC instruction field constants
    localparam MAC_OPCODE = 7'b0001011;
    localparam MAC_FUNCT3 = 3'b000;
    localparam MAC_FUNCT7 = 7'b0000001;
 
    always @(*) begin
        // Defaults
        reg_write  = 1'b0;
        mem_to_reg = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        alu_src    = 1'b0;
        alu_op     = ALU_ADD;
        branch     = 1'b0;
        jump       = 1'b0;
        mul_enable = 1'b0;
        div_enable = 1'b0;
        mac_enable = 1'b0;
 
        case (opcode)
            // R-type: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, MUL, DIV
            7'b0110011: begin
                reg_write = 1'b1;
                if (funct7 == 7'b0000001) begin
                    // M-extension
                    case (funct3)
                        3'b000: mul_enable = 1'b1; // MUL
                        3'b001: mul_enable = 1'b1; // MULH
                        3'b010: mul_enable = 1'b1; // MULHSU
                        3'b011: mul_enable = 1'b1; // MULHU
                        3'b100: div_enable = 1'b1; // DIV
                        3'b101: div_enable = 1'b1; // DIVU
                        default: mul_enable = 1'b1;
                    endcase
                end else begin
                    case (funct3)
                        3'b000: alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                        3'b001: alu_op = ALU_SLL;
                        3'b010: alu_op = ALU_SLT;
                        3'b011: alu_op = ALU_SLTU;
                        3'b100: alu_op = ALU_XOR;
                        3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                        3'b110: alu_op = ALU_OR;
                        3'b111: alu_op = ALU_AND;
                    endcase
                end
            end
 
            // I-type ALU: ADDI, SLTI, ANDI, ORI, XORI, SLLI, SRLI, SRAI
            7'b0010011: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    3'b001: alu_op = ALU_SLL;
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                endcase
            end
 
            // Load
            7'b0000011: begin
                reg_write  = 1'b1;
                mem_to_reg = 1'b1;
                mem_read   = 1'b1;
                alu_src    = 1'b1;
                alu_op     = ALU_ADD;
            end
 
            // Store
            7'b0100011: begin
                mem_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = ALU_ADD;
            end
 
            // Branch
            7'b1100011: begin
                branch = 1'b1;
                alu_op = ALU_SUB;
            end
 
            // JAL
            7'b1101111: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                alu_op    = ALU_ADD;
            end
 
            // JALR
            7'b1100111: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                alu_src   = 1'b1;
                alu_op    = ALU_ADD;
            end
 
            // LUI
            7'b0110111: begin
                if (funct7 == 7'd0 && funct3 == 3'd0) begin
                    reg_write = 1'b1;
                    alu_src   = 1'b1;
                    alu_op    = ALU_ADD;
                end
            end
 
            // AUIPC
            7'b0010111: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = ALU_ADD;
            end
 
            // Custom MAC instruction
            // Full encoding check: opcode + funct3 + funct7 must ALL match.
            // Prevents spurious mac_enable on reserved encodings that share
            // the same opcode but differ in funct3 or funct7.
            MAC_OPCODE: begin
                if (funct3 == MAC_FUNCT3 && funct7 == MAC_FUNCT7) begin
                    reg_write  = 1'b1;
                    mac_enable = 1'b1;
                end
                // else: unrecognized variant ? all outputs remain at default (NOP)
            end
 
            default: begin
                // NOP / unrecognized opcode
            end
        endcase
    end
endmodule
