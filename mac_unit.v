`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: mac_unit
// Description: 16x16 signed MAC with saturating 32-bit accumulator
//
// METHODOLOGY FIX (RESET-1):
//   Removed active-low rst_n port.
//   Added active-HIGH reset port to match all pipeline registers.
//   Removed clr_acc port (reset now handles both async clear and clr_acc).
//   riscv_mac_processor updated: .rst_n(~reset) removed, .reset(reset) used.
//
// Pipeline latency: 2 cycles
//   Cycle T   (en=1): booth_multiplier registers product; accum_out = old value
//   Cycle T+1 (en_d1=1): accumulator_adder adds product to accumulator
//////////////////////////////////////////////////////////////////////////////////
module mac_unit (
    input  wire        clk,
    input  wire        reset,       // Active-HIGH async reset (unified polarity)
    input  wire        en,          // Enable: high for 1 cycle when MAC is in EX
    input  wire [15:0] A,           // Operand A - lower 16 bits of Rs1 (signed)
    input  wire [15:0] B,           // Operand B - lower 16 bits of Rs2 (signed)
    output wire [31:0] accum_out,   // Saturated accumulator output
    output wire        mac_overflow // Sticky overflow flag
);

    // ?? Stage 1: Booth Multiplier ?????????????????????????????????????????
    wire [31:0] product;

    booth_multiplier mult (
        .clk    (clk),
        .reset  (reset),            // FIX: active-high reset (was rst_n active-low)
        .en     (en),
        .A      (A),
        .B      (B),
        .product(product)
    );

    // ?? Enable pipeline delay ?????????????????????????????????????????????
    // en is high exactly when MAC is in EX stage (1 cycle).
    // booth_multiplier registers the product on that cycle.
    // accumulator_adder must fire ONE cycle later (en_d1) when product is valid.
    reg en_d1;

    always @(posedge clk or posedge reset) begin   // FIX: posedge reset
        if (reset)
            en_d1 <= 1'b0;
        else
            en_d1 <= en;
    end

    // ?? Stage 2: Saturating Accumulator Adder ????????????????????????????
    wire [31:0] sum_out_w;
    wire        overflow_w;

    accumulator_adder adder (
        .clk         (clk),
        .reset       (reset),       // FIX: active-high reset (was rst_n active-low)
        .en          (en_d1),       // Delayed 1 cycle - fires when product is valid
        //.clr         (1'b0),        // Accumulator only clears on reset
        .product_in  (product),
        .sum_out     (sum_out_w),
        .mac_overflow(overflow_w)
    );

    assign accum_out    = sum_out_w;
    assign mac_overflow = overflow_w;

endmodule