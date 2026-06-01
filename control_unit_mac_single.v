`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.03.2026 05:43:16
// Design Name: 
// Module Name: control_unit_mac_single
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
module control_unit_mac_single (
    input         reset,
    input  [6:0]  funct7,
    input  [2:0]  funct3,
    input  [6:0]  opcode,

    // ?? RV32I ALU control ??
    output reg [5:0]  alu_control,

    // ?? Memory / branch / special signals ??
    output reg        lb,           // load enable
    output reg        mem_to_reg,   // write-back from memory
    output reg        bneq_control,
    output reg        beq_control,
    output reg        bgeq_control,
    output reg        blt_control,
    output reg        sw,           // store enable
    output reg        lui_control,
    output reg        reg_write,
    output reg        auipc_control,
    output reg        jalr_control,
    output reg        jal_control,

    // ?? RV32M unit control ??
    output reg        m_ext_enable,   // power gate: enables rv32m_unit
    output reg [2:0]  m_ext_op,       // which M-extension operation

    // ?? MAC unit control ??
    output reg        mac_enable,     // power gate: enables mac_wrapper
    output reg [2:0]  mac_operation   // which MAC operation
);

// ?? M-extension op codes ??
localparam MEXT_MUL    = 3'b000;
localparam MEXT_MULH   = 3'b001;
localparam MEXT_MULHSU = 3'b010;
localparam MEXT_MULHU  = 3'b011;
localparam MEXT_DIV    = 3'b100;
localparam MEXT_DIVU   = 3'b101;
localparam MEXT_REM    = 3'b110;
localparam MEXT_REMU   = 3'b111;

// ?? MAC op codes ??
localparam MAC_NOP   = 3'b000;
localparam MAC_CLEAR = 3'b001;
localparam MAC_ACC   = 3'b010;
localparam MAC_READ  = 3'b011;
localparam MAC_MULR  = 3'b100;
localparam MAC_NMAC  = 3'b101;

always @(*) begin
    // -------------------------------------------------------
    // Safe defaults - all units idle (power saving)
    // -------------------------------------------------------
    {lb, mem_to_reg, bneq_control, beq_control, bgeq_control,
     blt_control, sw, lui_control, reg_write,
     auipc_control, jal_control, jalr_control,
     mac_enable, m_ext_enable} = 14'd0;

    alu_control   = 6'd0;
    m_ext_op      = 3'd0;
    mac_operation = MAC_NOP;

    if (!reset) begin
        case (opcode)

            // ===================================================
            // R-TYPE  - RV32I (funct7?0000001) or RV32M (funct7=0000001)
            // ===================================================
            7'b0110011: begin
                if (funct7 == 7'b0000001) begin
                    // ?? RV32M: route to rv32m_unit, not ALU ??
                    reg_write    = 1'b1;
                    m_ext_enable = 1'b1;    // enable rv32m_unit
                    m_ext_op     = funct3;  // funct3 maps 1:1 to m_ext_op
                end else begin
                    // ?? RV32I: route to ALU ??
                    reg_write = 1'b1;
                    case ({funct7, funct3})
                        {7'b0000000, 3'b000}: alu_control = 6'b000001; // ADD
                        {7'b0100000, 3'b000}: alu_control = 6'b000010; // SUB
                        {7'b0000000, 3'b001}: alu_control = 6'b000011; // SLL
                        {7'b0000000, 3'b010}: alu_control = 6'b000100; // SLT
                        {7'b0000000, 3'b011}: alu_control = 6'b000101; // SLTU
                        {7'b0000000, 3'b100}: alu_control = 6'b000110; // XOR
                        {7'b0000000, 3'b101}: alu_control = 6'b000111; // SRL
                        {7'b0100000, 3'b101}: alu_control = 6'b100011; // SRA R-type (distinct from SRAI 001000)
                        {7'b0000000, 3'b110}: alu_control = 6'b001001; // OR
                        {7'b0000000, 3'b111}: alu_control = 6'b001010; // AND
                        default:              alu_control = 6'b000001;
                    endcase
                end
            end

            // ===================================================
            // I-TYPE ALU  (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
            // ===================================================
            7'b0010011: begin
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_control = 6'b001011; // ADDI
                    3'b001: alu_control = 6'b001100; // SLLI
                    3'b010: alu_control = 6'b001101; // SLTI
                    3'b011: alu_control = 6'b001110; // SLTIU
                    3'b100: alu_control = 6'b001111; // XORI
                    3'b101: alu_control = (funct7[5]) ? 6'b001000 : 6'b010000; // SRAI / SRLI
                    3'b110: alu_control = 6'b010001; // ORI
                    3'b111: alu_control = 6'b010010; // ANDI
                    default: alu_control = 6'b001011;
                endcase
            end

            // ===================================================
            // LOAD
            // ===================================================
            7'b0000011: begin
                lb        = 1'b1;
                mem_to_reg= 1'b1;
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_control = 6'b010011; // LB
                    3'b001: alu_control = 6'b010100; // LH
                    3'b010: alu_control = 6'b010101; // LW
                    3'b100: alu_control = 6'b010110; // LBU
                    3'b101: alu_control = 6'b010111; // LHU
                    default: alu_control = 6'b010101;
                endcase
            end

            // ===================================================
            // STORE
            // ===================================================
            7'b0100011: begin
                sw = 1'b1;
                case (funct3)
                    3'b000: alu_control = 6'b011000; // SB
                    3'b001: alu_control = 6'b011001; // SH
                    3'b010: alu_control = 6'b011010; // SW
                    default: alu_control = 6'b011010;
                endcase
            end

            // ===================================================
            // BRANCH
            // ===================================================
            7'b1100011: begin
                case (funct3)
                    3'b000: begin beq_control  = 1'b1; alu_control = 6'b011011; end // BEQ
                    3'b001: begin bneq_control = 1'b1; alu_control = 6'b011100; end // BNE
                    3'b100: begin blt_control  = 1'b1; alu_control = 6'b100000; end // BLT
                    3'b101: begin bgeq_control = 1'b1; alu_control = 6'b011111; end // BGE
                    3'b110: begin blt_control  = 1'b1; alu_control = 6'b100000; end // BLTU
                    3'b111: begin bgeq_control = 1'b1; alu_control = 6'b011111; end // BGEU
                    default: begin beq_control = 1'b1; alu_control = 6'b011011; end
                endcase
            end

            // ===================================================
            // LUI / AUIPC / JAL / JALR
            // ===================================================
            7'b0110111: begin // LUI
                lui_control = 1'b1;
                reg_write   = 1'b1;
                alu_control = 6'b100001;
            end
            7'b0010111: begin // AUIPC
                auipc_control = 1'b1;
                reg_write     = 1'b1;
                alu_control   = 6'b001011; // uses ADDI path: PC + U-imm
            end
            7'b1101111: begin // JAL
                jal_control = 1'b1;
                reg_write   = 1'b1;
                alu_control = 6'b100010;
            end
            7'b1100111: begin // JALR
                jalr_control = 1'b1;
                reg_write    = 1'b1;
                alu_control  = 6'b100010;
            end

            // ===================================================
            // CUSTOM-0 : MAC Instructions
            // ===================================================
            7'b0001011: begin
                mac_enable = 1'b1;
                case (funct3)
                    3'b000: begin mac_operation = MAC_CLEAR; reg_write = 1'b0; end // MACCLEAR
                    3'b001: begin mac_operation = MAC_ACC;   reg_write = 1'b0; end // MAC
                    3'b010: begin mac_operation = MAC_READ;  reg_write = 1'b1; end // MACREAD
                    3'b011: begin mac_operation = MAC_MULR;  reg_write = 1'b1; end // MACMULR
                    3'b100: begin mac_operation = MAC_NMAC;  reg_write = 1'b0; end // MACNMAC
                    default: begin mac_operation = MAC_NOP;  mac_enable = 1'b0; end
                endcase
            end

            // ===================================================
            // Default - NOP
            // ===================================================
            default: begin
                alu_control   = 6'b000001;
                m_ext_enable  = 1'b0;
                mac_enable    = 1'b0;
            end
        endcase
    end
end

endmodule
