`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: booth_multiplier
// Description: Radix-4 Booth encoding + Dadda CSA tree, 16x16 signed multiplier
//
// METHODOLOGY FIX (RESET-1):
//   Original used negedge rst_n (active-low async reset).
//   All pipeline registers in this design use posedge reset (active-high async).
//   Mixed reset polarity in the same clock domain is a critical Vivado
//   methodology violation (RESET-1) that can cause functional failures in hardware.
//   Changed to posedge reset to match the rest of the design.
//   mac_unit port updated accordingly (rst_n removed, reset added).
//////////////////////////////////////////////////////////////////////////////////
module booth_multiplier (
    input  wire        clk,
    input  wire        reset,          // Active-HIGH async reset (was rst_n active-low)
    input  wire        en,
    input  signed [15:0] A,
    input  signed [15:0] B,
    output reg signed [31:0] product
);

    // 1. Operand Isolation - zero inputs when not enabled
    wire signed [15:0] A_iso = en ? A : 16'sd0;
    wire signed [15:0] B_iso = en ? B : 16'sd0;

    // 2. Radix-4 Booth Encoding
    wire [16:0] B_ext = {B_iso, 1'b0};
    reg signed [31:0] pp [0:7];
    integer i;

    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            case (B_ext[2*i +: 3])
                3'b001, 3'b010: pp[i] = $signed(A_iso) <<< (2*i);
                3'b011:         pp[i] = $signed(A_iso) <<< (2*i + 1);
                3'b100:         pp[i] = -$signed(A_iso) <<< (2*i + 1);
                3'b101, 3'b110: pp[i] = -$signed(A_iso) <<< (2*i);
                default:        pp[i] = 32'sd0;
            endcase
        end
    end

    // 3. Dadda Tree Reduction Wires
    wire [31:0] s1_0, c1_0, s1_1, c1_1;
    wire [31:0] s2_0, c2_0, s2_1, c2_1;
    wire [31:0] s3_0, c3_0;
    wire [31:0] final_sum_vec, final_carry_vec;

    // Layer 1+
    csa_unit st1_0 (pp[0], pp[1], pp[2], s1_0, c1_0);
    csa_unit st1_1 (pp[3], pp[4], pp[5], s1_1, c1_1);
    // Layer 2 
    csa_unit st2_0 (s1_0, c1_0, s1_1, s2_0, c2_0);
    csa_unit st2_1 (c1_1, pp[6], pp[7], s2_1, c2_1);
    // Layer 3
    csa_unit st3_0 (s2_0, c2_0, s2_1, s3_0, c3_0);
    csa_unit st3_1 (s3_0, c3_0, c2_1, final_sum_vec, final_carry_vec);

    // 4. Final Addition - pipeline register (hold on en=0, reset on posedge reset)
    always @(posedge clk or posedge reset) begin   // FIX: posedge reset (was negedge rst_n)
        if (reset)
            product <= 32'sd0;
        else if (en)
            product <= final_sum_vec + final_carry_vec;
        // else: hold - accumulator_adder reads product one cycle after en drops
    end

endmodule