`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: riscv_mac_processor
//
// BRANCH FIX - three things were missing:
//   1. id_ex_register did not propagate id_branch -> ex_branch (now fixed)
//   2. alu zero output was unconnected (now fixed in alu.v)
//   3. pc_next was always pc_plus_4 - branch target never computed (fixed here)
//
// Branch implementation (resolves in EX stage - 2-cycle penalty):
//   branch_target  = ex_pc + ex_immediate  (B-type immediate from imm_gen)
//   branch_cond:
//     BEQ  funct3=000 : taken if alu_zero == 1  (rs1-rs2 == 0)
//     BNE  funct3=001 : taken if alu_zero == 0  (rs1-rs2 != 0)
//     BLT  funct3=100 : taken if alu_result[31] == 1 (signed less than)
//     BGE  funct3=101 : taken if alu_result[31]==0 && !alu_zero (signed >=)
//     BLTU funct3=110 : taken if forwarded_rs1 < forwarded_rs2 (unsigned)
//     BGEU funct3=111 : taken if forwarded_rs1 >= forwarded_rs2 (unsigned)
//   branch_taken   = ex_branch && branch_cond
//   pc_next        = branch_taken ? branch_target : pc_plus_4
//   branch_flush   = branch_taken
//     -> flushes IF/ID and ID/EX to squash 2 incorrectly fetched instructions
//////////////////////////////////////////////////////////////////////////////////
module riscv_mac_processor (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] pc_out,
    output wire [31:0] mac_output,
    output wire [31:0] result_out,
    output wire [4:0]  rd_out,
    output wire        reg_write_out
);

    // ?? Wire Declarations ?????????????????????????????????????????????????
    wire [31:0] pc, pc_next, pc_plus_4;
    wire [31:0] if_instruction;
    wire [31:0] id_pc, id_instruction;

    wire [6:0]  opcode;
    wire [4:0]  rs1, rs2, rd;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [31:0] immediate;
    wire [31:0] id_rs1_data, id_rs2_data, id_rd_data;
    wire        id_reg_write, id_mem_to_reg, id_mem_read, id_mem_write;
    wire        id_alu_src, id_branch, id_jump, id_mul_enable, id_mac_enable;
    wire [3:0]  id_alu_op;

    wire [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_rd_data, ex_immediate;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;
    wire [2:0]  ex_funct3;
    wire        ex_reg_write, ex_mem_to_reg, ex_mem_read, ex_mem_write;
    wire        ex_alu_src, ex_mul_enable, ex_branch;
    (* KEEP = "TRUE" *) wire        ex_mac_enable;
    wire [3:0]  ex_alu_op;
    wire [31:0] ex_alu_operand_a, ex_alu_operand_b;
    wire [31:0] ex_alu_result;
    wire        alu_zero;              // FIX: connected zero from ALU
    wire [63:0] ex_mul_product;
    (* KEEP = "TRUE" *) wire [31:0] ex_mac_result;
    wire        mac_overflow_flag;
    wire [31:0] ex_result;
    wire [1:0]  forward_a, forward_b, forward_rd;
    wire [31:0] forwarded_rs1, forwarded_rs2, forwarded_rd;

    // Branch wires
    wire [31:0] branch_target;        // ex_pc + ex_immediate
    wire        branch_cond;          // decoded from funct3 + alu_zero
    wire        branch_taken;         // ex_branch && branch_cond
    wire        branch_flush;         // flush 2 pipeline stages on taken branch

    wire [31:0] mem_alu_result, mem_rs2_data;
    wire [4:0]  mem_rd;
    wire [2:0]  mem_funct3;
    wire        mem_reg_write, mem_mem_to_reg, mem_mem_read, mem_mem_write;
    wire [31:0] mem_read_data;

    wire [31:0] wb_alu_result, wb_read_data;
    wire [4:0]  wb_rd;
    wire        wb_reg_write, wb_mem_to_reg;
    wire [31:0] wb_write_data;

    wire        load_stall, load_flush;  // from hazard unit

    // ?? Output Assignments ????????????????????????????????????????????????
    assign pc_out        = pc;
    assign mac_output    = ex_mac_result;
    assign result_out    = wb_write_data;
    assign rd_out        = wb_rd;
    assign reg_write_out = wb_reg_write;

    // ?? Hazard / Flush Signal Routing ?????????????????????????????????????
    // Stage   | Load-use hazard       | Branch taken
    // --------|----------------------|------------------------------
    // PC      | stall (hold)         | nothing
    // IF/ID   | stall (hold)         | flush (squash bad fetch)
    // ID/EX   | flush (insert bubble)| flush (squash bad decode)
    //
    // BUG FIXED: previously `flush = load_flush | branch_flush` was sent to
    // IF/ID.flush, which CLEARED IF/ID on a load-use hazard instead of holding it.
    // ID/EX had no flush port at all, so branches only squashed 1 stage not 2.
    wire pc_stall   = load_stall;                // PC holds
    wire ifid_stall = load_stall;                // IF/ID holds (was wrongly flushed)
    wire ifid_flush = branch_flush;              // IF/ID clears only on branch
    wire idex_flush = load_stall | branch_flush; // ID/EX inserts bubble on both

    // ?? Branch Logic (resolved in EX stage) ??????????????????????????????
    assign branch_target = ex_pc + ex_immediate;

    assign branch_cond =
        (ex_funct3 == 3'b000) ?  alu_zero :                          // BEQ
        (ex_funct3 == 3'b001) ? ~alu_zero :                          // BNE
        (ex_funct3 == 3'b100) ?  ex_alu_result[31] :                 // BLT  (signed)
        (ex_funct3 == 3'b101) ? ~ex_alu_result[31] & ~alu_zero :     // BGE  (signed)
        (ex_funct3 == 3'b110) ?  (forwarded_rs1 < forwarded_rs2) :   // BLTU (unsigned)
        (ex_funct3 == 3'b111) ? ~(forwarded_rs1 < forwarded_rs2) :   // BGEU (unsigned)
        1'b0;

    assign branch_taken = ex_branch & branch_cond;
    assign branch_flush = branch_taken;  // flush 2 incorrectly fetched instrs

    // ?? PC MUX ???????????????????????????????????????????????????????????
    assign pc_plus_4 = pc + 32'h00000004;
    assign pc_next   = branch_taken ? branch_target : pc_plus_4; // FIX: was always pc_plus_4

    // ?? IF Stage ??????????????????????????????????????????????????????????
    program_counter PC (
        .clk    (clk),
        .reset  (reset),
        .stall  (pc_stall),       // FIX: was (stall) - now uses separated signal
        .pc_next(pc_next),
        .pc     (pc)
    );

    instruction_memory IMEM (
        .address    (pc),
        .instruction(if_instruction)
    );

    if_id_register IF_ID (
        .clk           (clk),
        .reset         (reset),
        .stall         (ifid_stall),  // FIX: was (stall) - load-use stalls IF/ID
        .flush         (ifid_flush),  // FIX: was (flush) - only branch flushes IF/ID
        .if_pc         (pc),
        .if_instruction(if_instruction),
        .id_pc         (id_pc),
        .id_instruction(id_instruction)
    );

    // ?? ID Stage ??????????????????????????????????????????????????????????
    instruction_decoder DECODER (
        .instruction(id_instruction),
        .opcode     (opcode),
        .rd         (rd),
        .funct3     (funct3),
        .rs1        (rs1),
        .rs2        (rs2),
        .funct7     (funct7),
        .imm_i      (),
        .imm_s      (),
        .imm_b      (),
        .imm_u      (),
        .imm_j      ()
    );

    control_unit CONTROL (
        .opcode    (opcode),
        .funct3    (funct3),
        .funct7    (funct7),
        .reg_write (id_reg_write),
        .mem_to_reg(id_mem_to_reg),
        .mem_read  (id_mem_read),
        .mem_write (id_mem_write),
        .alu_src   (id_alu_src),
        .alu_op    (id_alu_op),
        .branch    (id_branch),
        .jump      (id_jump),
        .mul_enable(id_mul_enable),
        .div_enable(),
        .mac_enable(id_mac_enable)
    );

    immediate_generator IMMGEN (
        .instruction(id_instruction),
        .opcode     (opcode),
        .immediate  (immediate)
    );

    register_file REGFILE (
        .clk       (clk),
        .reset     (reset),
        .reg_write (wb_reg_write),
        .read_reg1 (rs1),
        .read_reg2 (rs2),
        .read_reg3 (rd),
        .write_reg (wb_rd),
        .write_data(wb_write_data),
        .read_data1(id_rs1_data),
        .read_data2(id_rs2_data),
        .read_data3(id_rd_data)
    );

    hazard_detection_unit HAZARD (
        .id_rs1      (rs1),
        .id_rs2      (rs2),
        .id_rd       (rd),
        .id_mac_enable(id_mac_enable),
        .ex_rd       (ex_rd),
        .ex_mem_read (ex_mem_read),
        .stall       (load_stall),
        .flush       (load_flush)
    );

    id_ex_register ID_EX (
        .clk          (clk),
        .reset        (reset),
        .flush        (idex_flush),   // FIX: was missing - squashes branch/load-use bubble
        .id_pc        (id_pc),
        .id_rs1_data  (id_rs1_data),
        .id_rs2_data  (id_rs2_data),
        .id_rd_data   (id_rd_data),
        .id_immediate (immediate),
        .id_rs1       (rs1),
        .id_rs2       (rs2),
        .id_rd        (rd),
        .id_funct3    (funct3),
        .id_reg_write (id_reg_write),
        .id_mem_to_reg(id_mem_to_reg),
        .id_mem_read  (id_mem_read),
        .id_mem_write (id_mem_write),
        .id_alu_src   (id_alu_src),
        .id_alu_op    (id_alu_op),
        .id_mul_enable(id_mul_enable),
        .id_mac_enable(id_mac_enable),
        .id_branch    (id_branch),     // FIX: connected
        .ex_pc        (ex_pc),
        .ex_rs1_data  (ex_rs1_data),
        .ex_rs2_data  (ex_rs2_data),
        .ex_rd_data   (ex_rd_data),
        .ex_immediate (ex_immediate),
        .ex_rs1       (ex_rs1),
        .ex_rs2       (ex_rs2),
        .ex_rd        (ex_rd),
        .ex_funct3    (ex_funct3),
        .ex_reg_write (ex_reg_write),
        .ex_mem_to_reg(ex_mem_to_reg),
        .ex_mem_read  (ex_mem_read),
        .ex_mem_write (ex_mem_write),
        .ex_alu_src   (ex_alu_src),
        .ex_alu_op    (ex_alu_op),
        .ex_mul_enable(ex_mul_enable),
        .ex_mac_enable(ex_mac_enable),
        .ex_branch    (ex_branch)      // FIX: connected
    );

    // ?? EX Stage ??????????????????????????????????????????????????????????
    forwarding_unit FORWARD (
        .ex_rs1      (ex_rs1),
        .ex_rs2      (ex_rs2),
        .ex_rd       (ex_rd),
        .mem_rd      (mem_rd),
        .mem_reg_write(mem_reg_write),
        .wb_rd       (wb_rd),
        .wb_reg_write(wb_reg_write),
        .mac_enable  (ex_mac_enable),
        .forward_a   (forward_a),
        .forward_b   (forward_b),
        .forward_rd  (forward_rd)
    );

    assign forwarded_rs1 = (forward_a == 2'b10) ? mem_alu_result :
                           (forward_a == 2'b01) ? wb_write_data  : ex_rs1_data;
    assign forwarded_rs2 = (forward_b == 2'b10) ? mem_alu_result :
                           (forward_b == 2'b01) ? wb_write_data  : ex_rs2_data;
    assign forwarded_rd  = (forward_rd == 2'b10) ? mem_alu_result :
                           (forward_rd == 2'b01) ? wb_write_data  : ex_rd_data;

    assign ex_alu_operand_a = forwarded_rs1;
    assign ex_alu_operand_b = ex_alu_src ? ex_immediate : forwarded_rs2;

    alu ALU (
        .operand_a (ex_alu_operand_a),
        .operand_b (ex_alu_operand_b),
        .alu_op    (ex_alu_op),
        .alu_result(ex_alu_result),
        .zero      (alu_zero)          // FIX: was ()
    );

    multiplier MULTIPLIER (
        .clk          (clk),
        .mul_enable   (ex_mul_enable),
        .multiplicand (forwarded_rs1),
        .multiplier_in(forwarded_rs2),
        .funct3       (ex_funct3),
        .product      (ex_mul_product),
        .mul_ready    ()
    );

    (* DONT_TOUCH = "TRUE" *)
    mac_unit MAC (
        .clk         (clk),
        .reset       (reset),
        .en          (ex_mac_enable),
        .A           (forwarded_rs1[15:0]),
        .B           (forwarded_rs2[15:0]),
        .accum_out   (ex_mac_result),
        .mac_overflow(mac_overflow_flag)
    );

    assign ex_result = ex_mac_enable ? ex_mac_result        :
                       ex_mul_enable ? ex_mul_product[31:0] :
                       ex_alu_result;

    // ?? EX/MEM ????????????????????????????????????????????????????????????
    ex_mem_register EX_MEM (
        .clk           (clk),
        .reset         (reset),
        .ex_alu_result (ex_result),
        .ex_rs2_data   (forwarded_rs2),
        .ex_rd         (ex_rd),
        .ex_funct3     (ex_funct3),
        .ex_reg_write  (ex_reg_write),
        .ex_mem_to_reg (ex_mem_to_reg),
        .ex_mem_read   (ex_mem_read),
        .ex_mem_write  (ex_mem_write),
        .mem_alu_result(mem_alu_result),
        .mem_rs2_data  (mem_rs2_data),
        .mem_rd        (mem_rd),
        .mem_funct3    (mem_funct3),
        .mem_reg_write (mem_reg_write),
        .mem_mem_to_reg(mem_mem_to_reg),
        .mem_mem_read  (mem_mem_read),
        .mem_mem_write (mem_mem_write)
    );

    // ?? MEM Stage ?????????????????????????????????????????????????????????
    data_memory DMEM (
        .clk       (clk),
        .mem_read  (mem_mem_read),
        .mem_write (mem_mem_write),
        .funct3    (mem_funct3),
        .address   (mem_alu_result),
        .write_data(mem_rs2_data),
        .read_data (mem_read_data)
    );

    // ?? MEM/WB ????????????????????????????????????????????????????????????
    mem_wb_register MEM_WB (
        .clk           (clk),
        .reset         (reset),
        .mem_alu_result(mem_alu_result),
        .mem_read_data (mem_read_data),
        .mem_rd        (mem_rd),
        .mem_reg_write (mem_reg_write),
        .mem_mem_to_reg(mem_mem_to_reg),
        .wb_alu_result (wb_alu_result),
        .wb_read_data  (wb_read_data),
        .wb_rd         (wb_rd),
        .wb_reg_write  (wb_reg_write),
        .wb_mem_to_reg (wb_mem_to_reg)
    );

    // ?? WB Stage ??????????????????????????????????????????????????????????
    assign wb_write_data = wb_mem_to_reg ? wb_read_data : wb_alu_result;

endmodule