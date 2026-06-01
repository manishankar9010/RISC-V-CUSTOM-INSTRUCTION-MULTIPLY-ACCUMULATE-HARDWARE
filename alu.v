`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: alu
// FIX: zero output was tied to () - now properly connected.
//      Used by branch condition logic in riscv_mac_processor.
//////////////////////////////////////////////////////////////////////////////////
(* keep_hierarchy = "yes" *)
module alu (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [3:0]  alu_op,
    output reg  [31:0] alu_result,
    output wire        zero
);
    always @(*) begin
        case (alu_op)
            4'd0: alu_result = operand_a + operand_b;
            4'd1: alu_result = operand_a - operand_b;
            4'd2: alu_result = operand_a & operand_b;
            4'd3: alu_result = operand_a | operand_b;
            4'd4: alu_result = operand_a ^ operand_b;
            4'd5: alu_result = operand_a << operand_b[4:0];
            4'd6: alu_result = operand_a >> operand_b[4:0];
            4'd7: alu_result = $signed(operand_a) >>> operand_b[4:0];
            4'd8: alu_result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
            4'd9: alu_result = (operand_a < operand_b) ? 32'd1 : 32'd0;
            default: alu_result = 32'h00000000;
        endcase
    end
    assign zero = (alu_result == 32'h00000000);
endmodule