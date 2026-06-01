`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: id_ex_register
//
// FIXES APPLIED:
//   FIX-1: Added id_branch -> ex_branch propagation (was missing, branches had no effect).
//   FIX-2: Added flush input port.
//          Without this, a taken branch only flushed IF/ID but NOT ID/EX.
//          The instruction that was in the ID stage when the branch resolved
//          would silently slip into EX and execute - causing 1 wrong instruction
//          to run after every taken branch.
//          Flush is also used by the load-use hazard to insert a bubble in EX.
//          Priority: reset > flush > normal latch
//////////////////////////////////////////////////////////////////////////////////
module id_ex_register (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,          // FIX-2: squash this stage (branch or load-use)
    // ID stage inputs
    input  wire [31:0] id_pc,
    input  wire [31:0] id_rs1_data,
    input  wire [31:0] id_rs2_data,
    input  wire [31:0] id_rd_data,
    input  wire [31:0] id_immediate,
    input  wire [4:0]  id_rs1,
    input  wire [4:0]  id_rs2,
    input  wire [4:0]  id_rd,
    input  wire [2:0]  id_funct3,
    input  wire        id_reg_write,
    input  wire        id_mem_to_reg,
    input  wire        id_mem_read,
    input  wire        id_mem_write,
    input  wire        id_alu_src,
    input  wire [3:0]  id_alu_op,
    input  wire        id_mul_enable,
    input  wire        id_mac_enable,
    input  wire        id_branch,      // FIX-1: was missing
    // EX stage outputs
    output reg  [31:0] ex_pc,
    output reg  [31:0] ex_rs1_data,
    output reg  [31:0] ex_rs2_data,
    output reg  [31:0] ex_rd_data,
    output reg  [31:0] ex_immediate,
    output reg  [4:0]  ex_rs1,
    output reg  [4:0]  ex_rs2,
    output reg  [4:0]  ex_rd,
    output reg  [2:0]  ex_funct3,
    output reg         ex_reg_write,
    output reg         ex_mem_to_reg,
    output reg         ex_mem_read,
    output reg         ex_mem_write,
    output reg         ex_alu_src,
    output reg  [3:0]  ex_alu_op,
    output reg         ex_mul_enable,
    output reg         ex_mac_enable,
    output reg         ex_branch       // FIX-1: was missing
);

    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin      // FIX-2: flush inserts NOP bubble into EX
            ex_pc         <= 32'h0;
            ex_rs1_data   <= 32'h0;
            ex_rs2_data   <= 32'h0;
            ex_rd_data    <= 32'h0;
            ex_immediate  <= 32'h0;
            ex_rs1        <= 5'h0;
            ex_rs2        <= 5'h0;
            ex_rd         <= 5'h0;
            ex_funct3     <= 3'h0;
            ex_reg_write  <= 1'b0;     // no write-back
            ex_mem_to_reg <= 1'b0;
            ex_mem_read   <= 1'b0;
            ex_mem_write  <= 1'b0;
            ex_alu_src    <= 1'b0;
            ex_alu_op     <= 4'h0;
            ex_mul_enable <= 1'b0;
            ex_mac_enable <= 1'b0;
            ex_branch     <= 1'b0;
        end else begin
            ex_pc         <= id_pc;
            ex_rs1_data   <= id_rs1_data;
            ex_rs2_data   <= id_rs2_data;
            ex_rd_data    <= id_rd_data;
            ex_immediate  <= id_immediate;
            ex_rs1        <= id_rs1;
            ex_rs2        <= id_rs2;
            ex_rd         <= id_rd;
            ex_funct3     <= id_funct3;
            ex_reg_write  <= id_reg_write;
            ex_mem_to_reg <= id_mem_to_reg;
            ex_mem_read   <= id_mem_read;
            ex_mem_write  <= id_mem_write;
            ex_alu_src    <= id_alu_src;
            ex_alu_op     <= id_alu_op;
            ex_mul_enable <= id_mul_enable;
            ex_mac_enable <= id_mac_enable;
            ex_branch     <= id_branch;    // FIX-1: propagate branch signal
        end
    end
endmodule