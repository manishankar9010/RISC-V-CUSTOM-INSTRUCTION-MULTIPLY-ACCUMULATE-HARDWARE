`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.03.2026 14:03:31
// Design Name: 
// Module Name: ex_mem_register
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
module ex_mem_register (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] ex_alu_result,
    input  wire [31:0] ex_rs2_data,
    input  wire [4:0]  ex_rd,
    input  wire [2:0]  ex_funct3,
    input  wire        ex_reg_write,
    input  wire        ex_mem_to_reg,
    input  wire        ex_mem_read,
    input  wire        ex_mem_write,
    output reg  [31:0] mem_alu_result,
    output reg  [31:0] mem_rs2_data,
    output reg  [4:0]  mem_rd,
    output reg  [2:0]  mem_funct3,
    output reg         mem_reg_write,
    output reg         mem_mem_to_reg,
    output reg         mem_mem_read,
    output reg         mem_mem_write
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_alu_result <= 32'h0;
            mem_rs2_data   <= 32'h0;
            mem_rd         <= 5'h0;
            mem_funct3     <= 3'h0;
            mem_reg_write  <= 1'b0;
            mem_mem_to_reg <= 1'b0;
            mem_mem_read   <= 1'b0;
            mem_mem_write  <= 1'b0;
        end else begin
            mem_alu_result <= ex_alu_result;
            mem_rs2_data   <= ex_rs2_data;
            mem_rd         <= ex_rd;
            mem_funct3     <= ex_funct3;
            mem_reg_write  <= ex_reg_write;
            mem_mem_to_reg <= ex_mem_to_reg;
            mem_mem_read   <= ex_mem_read;
            mem_mem_write  <= ex_mem_write;
        end
    end
endmodule
