`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: accumulator_adder
// Description: Saturating 32-bit signed accumulator
//
// METHODOLOGY FIX (RESET-1):
//   Original used negedge rst_n (active-low async reset).
//   All pipeline registers in this design use posedge reset (active-high async).
//   Changed to posedge reset to unify reset polarity across the design.
//   mac_unit and riscv_mac_processor updated accordingly.
//////////////////////////////////////////////////////////////////////////////////
module accumulator_adder (
    input  wire        clk,
    input  wire        reset,          // Active-HIGH async reset (was rst_n active-low)
    input  wire        en,
    //input  wire        clr,            // Synchronous clear of accumulator
    input  signed [31:0] product_in,
    output reg  signed [31:0] sum_out,
    output reg         mac_overflow
);

    // 33-bit addition for signed overflow detection
    wire signed [32:0] next_sum = $signed(sum_out) + $signed(product_in);

    always @(posedge clk or posedge reset) begin   // FIX: posedge reset (was negedge rst_n)
        if (reset) begin
            sum_out      <= 32'sd0;
            mac_overflow <= 1'b0;
        end /*else if (clr) begin
            sum_out      <= 32'sd0;
            mac_overflow <= 1'b0;
        end */else if (en) begin
            // Signed saturation logic
            if (sum_out[31] == 0 && product_in[31] == 0 && next_sum[31] == 1) begin
                sum_out      <= 32'h7FFFFFFF;  // Positive saturation
                mac_overflow <= 1'b1;
            end else if (sum_out[31] == 1 && product_in[31] == 1 && next_sum[31] == 0) begin
                sum_out      <= 32'h80000000;  // Negative saturation
                mac_overflow <= 1'b1;
            end else begin
                sum_out      <= next_sum[31:0];
                mac_overflow <= 1'b0;
            end
        end
    end
endmodule