`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: multiplier
// Description: Shared combinational multiplier for RV32IM M-extension
//              (MUL, MULH, MULHSU, MULHU)
//
// SYNTHESIS FIX:
//   REMOVED (* use_dsp = "yes" *) from wire declarations.
//   This attribute is ONLY valid on registers and module ports, NOT on wires.
//   Placing it on wires caused Vivado to enter an infinite retry loop trying
//   to force-map combinational nets onto DSP48 block inputs, causing synthesis
//   to hang for 30+ minutes.
//   Vivado will still infer DSP48 blocks automatically for 32x32 multiply
//   operations without needing the explicit attribute. Expected: 4 DSP48E1
//   blocks per 32x32 multiply on XC7Z020 (DSP48E1 is 18x18 internally).
//////////////////////////////////////////////////////////////////////////////////
module multiplier (
    input  wire        clk,           // kept for port compatibility, unused
    input  wire        mul_enable,
    input  wire [31:0] multiplicand,
    input  wire [31:0] multiplier_in,
    input  wire [2:0]  funct3,
    output wire [63:0] product,
    output wire        mul_ready
);

    // No (* use_dsp = "yes" *) on wires - Vivado infers DSPs automatically
    wire [63:0] signed_product;
    wire [63:0] unsigned_product;
    wire [63:0] signed_unsigned_product;

    assign signed_product          = $signed(multiplicand) * $signed(multiplier_in);
    assign unsigned_product        = multiplicand           * multiplier_in;
    assign signed_unsigned_product = $signed(multiplicand) * multiplier_in;

    assign product = mul_enable ?
                     (funct3 == 3'b001 ? signed_product          : // MULH
                      funct3 == 3'b010 ? signed_unsigned_product : // MULHSU
                      funct3 == 3'b011 ? unsigned_product        : // MULHU
                                         signed_product)           // MUL (lower 32)
                     : 64'h0;

    assign mul_ready = mul_enable;

endmodule