`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.03.2026 14:00:09
// Design Name: 
// Module Name: forwarding_unit
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
module forwarding_unit (
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,
    input  wire [4:0] ex_rd,
    input  wire [4:0] mem_rd,
    input  wire       mem_reg_write,
    input  wire [4:0] wb_rd,
    input  wire       wb_reg_write,
    input  wire       mac_enable,
    output reg  [1:0] forward_a,   // 00=regfile, 10=MEM, 01=WB
    output reg  [1:0] forward_b,
    output reg  [1:0] forward_rd   // For MAC accumulator (rd current value)
);
    always @(*) begin
        // Forward rs1 (operand A)
        if (mem_reg_write && mem_rd != 5'b0 && mem_rd == ex_rs1)
            forward_a = 2'b10; // From MEM stage
        else if (wb_reg_write && wb_rd != 5'b0 && wb_rd == ex_rs1)
            forward_a = 2'b01; // From WB stage
        else
            forward_a = 2'b00; // From register file

        // Forward rs2 (operand B)
        if (mem_reg_write && mem_rd != 5'b0 && mem_rd == ex_rs2)
            forward_b = 2'b10; // From MEM stage
        else if (wb_reg_write && wb_rd != 5'b0 && wb_rd == ex_rs2)
            forward_b = 2'b01; // From WB stage
        else
            forward_b = 2'b00; // From register file

        // Forward rd (MAC accumulator current value)
        if (mac_enable) begin
            if (mem_reg_write && mem_rd != 5'b0 && mem_rd == ex_rd)
                forward_rd = 2'b10;
            else if (wb_reg_write && wb_rd != 5'b0 && wb_rd == ex_rd)
                forward_rd = 2'b01;
            else
                forward_rd = 2'b00;
        end else begin
            forward_rd = 2'b00;
        end
    end
endmodule
