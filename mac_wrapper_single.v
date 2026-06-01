`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.03.2026 05:46:27
// Design Name: 
// Module Name: mac_wrapper_single
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
module mac_wrapper_single (
    input wire        clk,
    input wire        rst_n,
    input wire        mac_enable,
    input wire [2:0]  mac_operation,
    input wire [15:0] operand_a,
    input wire [15:0] operand_b,
    output wire [31:0] mac_result,
    output wire [31:0] mac_accum_out,
    output wire        mac_overflow
);

localparam MAC_NOP   = 3'b000;
localparam MAC_CLEAR = 3'b001;
localparam MAC_ACC   = 3'b010;
localparam MAC_READ  = 3'b011;  // note: was 3 but READ is 011 in control, MULR=100 now
localparam MAC_MULR  = 3'b100;  // Wait -- aligning with control unit
localparam MAC_NMAC  = 3'b101;

// Power gating signals
wire do_mac  = mac_enable && (mac_operation == MAC_ACC);
wire do_nmac = mac_enable && (mac_operation == MAC_NMAC);
wire do_clr  = mac_enable && (mac_operation == MAC_CLEAR);
wire do_mulr = mac_enable && (mac_operation == MAC_MULR);

// Instantiate core MAC (handles ACC and CLEAR)
mac_unit mac_core (
    .clk     (clk),
    .rst_n   (rst_n),
    .en      (do_mac),
    .clr_acc (do_clr),
    .A       (operand_a),
    .B       (operand_b),
    .accum_out(mac_accum_out),
    .mac_overflow(mac_overflow)
);

// Negation-accumulate: subtract product
// We add a signed product to the accumulator (handled via negate path)
// For NMAC: we feed -A into mac_unit using a separate product path
wire signed [31:0] nmac_product;
reg  signed [31:0] nmac_accum;
wire signed [15:0] neg_a = -$signed(operand_a);

booth_multiplier nmac_mult (
    .clk    (clk),
    .en     (do_nmac),
    .rst_n  (rst_n),
    .A      (neg_a),
    .B      (operand_b),
    .product(nmac_product)
);

// MULR: single multiply result direct to register (no accumulation)
wire signed [31:0] mulr_product;
booth_multiplier mulr_mult (
    .clk    (clk),
    .en     (do_mulr),
    .rst_n  (rst_n),
    .A      (operand_a),
    .B      (operand_b),
    .product(mulr_product)
);

// Result mux
assign mac_result =
    (mac_operation == MAC_READ) ? mac_accum_out :
    (mac_operation == MAC_MULR) ? mulr_product  :
    32'h0;

endmodule
