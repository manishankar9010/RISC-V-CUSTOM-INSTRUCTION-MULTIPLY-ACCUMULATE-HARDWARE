`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.03.2026 07:33:18
// Design Name: 
// Module Name: rv32m_unit
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
module rv32m_unit (
    // Enable from control unit (power gate - all logic idles when 0)
    input        m_ext_enable,
    // Operation selector
    input  [2:0] m_ext_op,
    // Operands (after forwarding mux in datapath)
    input  [31:0] rs1,
    input  [31:0] rs2,
    // Result
    output reg [31:0] result
);

// -----------------------------------------------------------------------
// Operation encoding
// -----------------------------------------------------------------------
localparam MUL    = 3'b000;
localparam MULH   = 3'b001;
localparam MULHSU = 3'b010;
localparam MULHU  = 3'b011;
localparam DIV    = 3'b100;
localparam DIVU   = 3'b101;
localparam REM    = 3'b110;
localparam REMU   = 3'b111;

// -----------------------------------------------------------------------
// Power-gated operand isolation
// When m_ext_enable=0 the multiplier sees 0×0, saving dynamic power.
// -----------------------------------------------------------------------
wire [31:0] op1 = m_ext_enable ? rs1 : 32'd0;
wire [31:0] op2 = m_ext_enable ? rs2 : 32'd0;

// -----------------------------------------------------------------------
// 64-bit products
// -----------------------------------------------------------------------
wire signed [63:0] prod_ss = $signed(op1) * $signed(op2);           // signed × signed
wire signed [63:0] prod_su = $signed(op1) * $signed({1'b0, op2});   // signed × unsigned
wire        [63:0] prod_uu = op1 * op2;                              // unsigned × unsigned

// -----------------------------------------------------------------------
// Divide / Remainder protection wires
// -----------------------------------------------------------------------
wire div_by_zero = (op2 == 32'd0);
wire signed_ovf  = (op1 == 32'h8000_0000) && (op2 == 32'hFFFF_FFFF);

// Signed divide
wire signed [31:0] quot_s =
    div_by_zero  ? 32'hFFFF_FFFF :
    signed_ovf   ? 32'h8000_0000 :
    $signed(op1) / $signed(op2);

// Unsigned divide
wire [31:0] quot_u =
    div_by_zero ? 32'hFFFF_FFFF : op1 / op2;

// Signed remainder
wire signed [31:0] rem_s =
    div_by_zero ? $signed(op1) :
    signed_ovf  ? 32'd0        :
    $signed(op1) % $signed(op2);

// Unsigned remainder
wire [31:0] rem_u =
    div_by_zero ? op1 : op1 % op2;

// -----------------------------------------------------------------------
// Result mux
// -----------------------------------------------------------------------
always @(*) begin
    if (!m_ext_enable) begin
        result = 32'd0;   // idle: zero output (power saving)
    end else begin
        case (m_ext_op)
            MUL   : result = prod_ss[31:0];    // lower 32 bits
            MULH  : result = prod_ss[63:32];   // upper 32 bits signed×signed
            MULHSU: result = prod_su[63:32];   // upper 32 bits signed×unsigned
            MULHU : result = prod_uu[63:32];   // upper 32 bits unsigned×unsigned
            DIV   : result = quot_s;
            DIVU  : result = quot_u;
            REM   : result = rem_s;
            REMU  : result = rem_u;
            default: result = 32'd0;
        endcase
    end
end

endmodule