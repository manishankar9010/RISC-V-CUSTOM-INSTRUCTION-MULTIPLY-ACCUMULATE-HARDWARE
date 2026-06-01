`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.03.2026 14:05:00
// Design Name: 
// Module Name: mem_wb_register
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
module mem_wb_register (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] mem_alu_result,
    input  wire [31:0] mem_read_data,
    input  wire [4:0]  mem_rd,
    input  wire        mem_reg_write,
    input  wire        mem_mem_to_reg,
    output reg  [31:0] wb_alu_result,
    output reg  [31:0] wb_read_data,
    output reg  [4:0]  wb_rd,
    output reg         wb_reg_write,
    output reg         wb_mem_to_reg
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wb_alu_result <= 32'h0;
            wb_read_data  <= 32'h0;
            wb_rd         <= 5'h0;
            wb_reg_write  <= 1'b0;
            wb_mem_to_reg <= 1'b0;
        end else begin
            wb_alu_result <= mem_alu_result;
            wb_read_data  <= mem_read_data;
            wb_rd         <= mem_rd;
            wb_reg_write  <= mem_reg_write;
            wb_mem_to_reg <= mem_mem_to_reg;
        end
    end
endmodule