`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.03.2026 13:57:32
// Design Name: 
// Module Name: register_file
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
module register_file (
    input  wire        clk,
    input  wire        reset,
    input  wire        reg_write,
    input  wire [4:0]  read_reg1,
    input  wire [4:0]  read_reg2,
    input  wire [4:0]  read_reg3,   // For MAC: read current rd value
    input  wire [4:0]  write_reg,
    input  wire [31:0] write_data,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2,
    output wire [31:0] read_data3
);
    reg [31:0] registers [0:31];
    integer i;

    // Write on rising edge (x0 always stays 0)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'h00000000;
        end else if (reg_write && write_reg != 5'b00000) begin
            registers[write_reg] <= write_data;
        end
    end

    // Write-first read: if reading same reg being written this cycle, forward new value
    assign read_data1 = (reg_write && write_reg == read_reg1 && write_reg != 5'b0)
                        ? write_data : registers[read_reg1];
    assign read_data2 = (reg_write && write_reg == read_reg2 && write_reg != 5'b0)
                        ? write_data : registers[read_reg2];
    assign read_data3 = (reg_write && write_reg == read_reg3 && write_reg != 5'b0)
                        ? write_data : registers[read_reg3];
endmodule
