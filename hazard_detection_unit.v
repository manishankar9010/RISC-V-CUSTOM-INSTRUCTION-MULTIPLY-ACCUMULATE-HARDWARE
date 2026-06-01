`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.03.2026 13:58:34
// Design Name: 
// Module Name: hazard_detection_unit
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
module hazard_detection_unit (
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,
    input  wire [4:0] id_rd,
    input  wire       id_mac_enable,
    input  wire [4:0] ex_rd,
    input  wire       ex_mem_read,
    output reg        stall,
    output reg        flush
);
    always @(*) begin
        // Load-use hazard: EX stage is a LOAD and ID stage reads same register
        if (ex_mem_read &&
            (ex_rd == id_rs1 || ex_rd == id_rs2 ||
             (id_mac_enable && ex_rd == id_rd))) begin
            stall = 1'b1;
            flush = 1'b1;
        end else begin
            stall = 1'b0;
            flush = 1'b0;
        end
    end
endmodule
