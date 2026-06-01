`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.03.2026 14:25:48
// Design Name: 
// Module Name: riscv_mac_processor_tb
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
module riscv_mac_processor_tb;
 
    // ?? DUT Ports ?????????????????????????????????????????????????????????
    reg         clk;
    reg         reset;
    wire [31:0] pc_out;
 
    // ?? DUT Instance ??????????????????????????????????????????????????????
    riscv_mac_processor uut (
        .clk    (clk),
        .reset  (reset),
        .pc_out (pc_out)
    );
 
    // ?? Clock : 10 ns period (100 MHz) ????????????????????????????????????
    initial  clk = 1'b0;
    always #5 clk = ~clk;
 
    // ?? Pass / Fail Counters ??????????????????????????????????????????????
    integer pass_count;
    integer fail_count;
 
    initial begin
        pass_count = 0;
        fail_count = 0;
    end
 
    // ========================================================================
    // task : check_reg
    //   Reads register[reg_num] via hierarchical path and compares to expected.
    //   Prints PASS / FAIL with the assembly mnemonic for easy identification.
    // ========================================================================
    task check_reg;
        input [4:0]   reg_num;
        input [31:0]  expected;
        input [239:0] label;        // up to 30 ASCII characters
        reg   [31:0]  actual;
        begin
            actual = uut.REGFILE.registers[reg_num];
            if (actual === expected) begin
                $display("  PASS | %s | x%0d = %0d", label, reg_num, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %s | x%0d = %0d  (expected %0d)",
                         label, reg_num, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask
 
    // ========================================================================
    // task : check_mem
    //   Reads data_memory[word_index] and compares to expected.
    //   word_index = byte_address / 4  (data memory is word-indexed internally)
    // ========================================================================
    task check_mem;
        input [31:0]  word_index;
        input [31:0]  expected;
        input [239:0] label;
        reg   [31:0]  actual;
        begin
            actual = uut.DMEM.memory[word_index];
            if (actual === expected) begin
                $display("  PASS | %s | mem[%0d] = %0d", label, word_index, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %s | mem[%0d] = %0d  (expected %0d)",
                         label, word_index, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask
 
    // ========================================================================
    // Test Program - loaded directly into IMEM
    //
    // All instructions below use x1=5, x2=3 as operands (set by the two
    // leading ADDIs). The full encoding table:
    //
    //  Word  Hex Encoding  Assembly                 Expected
    //  ????  ????????????  ???????????????????????  ?????????????????????????
    //  [ 0]  00500093      ADDI  x1,  x0,  5        x1  = 5
    //  [ 1]  00300113      ADDI  x2,  x0,  3        x2  = 3
    //  [ 2]  00000013      NOP
    //  [ 3]  002081B3      ADD   x3,  x1,  x2       x3  = 8     (5+3)
    //  [ 4]  40208233      SUB   x4,  x1,  x2       x4  = 2     (5-3)
    //  [ 5]  0020F2B3      AND   x5,  x1,  x2       x5  = 1     (5&3)
    //  [ 6]  0020E333      OR    x6,  x1,  x2       x6  = 7     (5|3)
    //  [ 7]  0020C3B3      XOR   x7,  x1,  x2       x7  = 6     (5^3)
    //  [ 8]  00209413      SLLI  x8,  x1,  2        x8  = 20    (5<<2)
    //  [ 9]  0011D493      SRLI  x9,  x3,  1        x9  = 4     (8>>1)
    //  [10]  00122533      SLT   x10, x4,  x1       x10 = 1     (2<5 ? true)
    //  [11]  00102023      SW    x1,  0(x0)         mem[0] = 5
    //  [12]  00002583      LW    x11, 0(x0)         x11 = 5
    //  [13]  02208633      MUL   x12, x1,  x2       x12 = 15    (5×3)
    //  [14]  00000013      NOP  ??
    //  [15]  00000013      NOP   ? pipeline drain before MAC
    //  [16]  00000013      NOP  ??
    //  [17]  0220868B      MAC   x13, x1,  x2       x13 = 0  ? accum BEFORE this MAC
    //  [18]  00000013      NOP  ??                  internally: accum ? 15
    //  [19]  00000013      NOP   ? 4 NOPs so accum settles before next MAC
    //  [20]  00000013      NOP   ?
    //  [21]  00000013      NOP  ??
    //  [22]  0220870B      MAC   x14, x1,  x2       x14 = 15 ? accum after MAC1
    //  [23]  00000013      NOP  ??                  internally: accum ? 30
    //  [24]  00000013      NOP   ?
    //  [25]  00000013      NOP   ?
    //  [26]  00000013      NOP  ??
    //  [27]  0220878B      MAC   x15, x1,  x2       x15 = 30 ? accum after MAC2
    //  [28]  00000013      NOP  ??                  internally: accum ? 45
    //  [29]  00000013      NOP   ? drain so accum_out is stable before final check
    //  [30]  00000013      NOP   ?
    //  [31]  00000013      NOP  ??
    //
    // MAC Note - 2-cycle internal pipeline:
    //   When MAC is in the EX stage at time T:
    //     • ex_result captures accum_out = OLD accumulated value
    //     • T+1: Booth multiplier registers the product (5×3 = 15)
    //     • T+2: accumulator_adder registers old_accum + 15
    //   So the register file receives the accumulated result from
    //   ALL PREVIOUS MACs, not the current one. Three consecutive MACs
    //   produce: x13=0, x14=15, x15=30  (accumulator ends at 45).
    // ========================================================================
 
    initial begin
        // #1: ensure this initial block overrides any $readmemh inside
        // instruction_memory (initial block ordering is non-deterministic at t=0)
        #1;
 
        // Fill all 256 words with NOP first
        begin : fill_nop
            integer idx;
            for (idx = 0; idx < 256; idx = idx + 1)
                uut.IMEM.memory[idx] = 32'h00000013;
        end
 
        // ?? Immediate ???????????????????????????????????????????????????
        uut.IMEM.memory[ 0] = 32'h00500093; // ADDI  x1,  x0, 5
        uut.IMEM.memory[ 1] = 32'h00300113; // ADDI  x2,  x0, 3
 
        // ?? NOP gap ?????????????????????????????????????????????????????
        uut.IMEM.memory[ 2] = 32'h00000013; // NOP
 
        // ?? R-Type Arithmetic ???????????????????????????????????????????
        uut.IMEM.memory[ 3] = 32'h002081B3; // ADD   x3,  x1, x2
        uut.IMEM.memory[ 4] = 32'h40208233; // SUB   x4,  x1, x2
        uut.IMEM.memory[ 5] = 32'h0020F2B3; // AND   x5,  x1, x2
        uut.IMEM.memory[ 6] = 32'h0020E333; // OR    x6,  x1, x2
        uut.IMEM.memory[ 7] = 32'h0020C3B3; // XOR   x7,  x1, x2
 
        // ?? Shift & Compare ?????????????????????????????????????????????
        uut.IMEM.memory[ 8] = 32'h00209413; // SLLI  x8,  x1, 2
        uut.IMEM.memory[ 9] = 32'h0011D493; // SRLI  x9,  x3, 1
        uut.IMEM.memory[10] = 32'h00122533; // SLT   x10, x4, x1
 
        // ?? Load / Store ????????????????????????????????????????????????
        uut.IMEM.memory[11] = 32'h00102023; // SW    x1,  0(x0)
        uut.IMEM.memory[12] = 32'h00002583; // LW    x11, 0(x0)
 
        // ?? MUL (M-Extension) ???????????????????????????????????????????
        uut.IMEM.memory[13] = 32'h02208633; // MUL   x12, x1, x2
 
        // ?? Pipeline drain before MAC ???????????????????????????????????
        uut.IMEM.memory[14] = 32'h00000013;
        uut.IMEM.memory[15] = 32'h00000013;
        uut.IMEM.memory[16] = 32'h00000013;
 
        // ?? MAC Instruction × 3 (custom opcode=0001011) ?????????????????
        uut.IMEM.memory[17] = 32'h0220868B; // MAC   x13, x1, x2
        uut.IMEM.memory[18] = 32'h00000013;
        uut.IMEM.memory[19] = 32'h00000013;
        uut.IMEM.memory[20] = 32'h00000013;
        uut.IMEM.memory[21] = 32'h00000013;
        uut.IMEM.memory[22] = 32'h0220870B; // MAC   x14, x1, x2
        uut.IMEM.memory[23] = 32'h00000013;
        uut.IMEM.memory[24] = 32'h00000013;
        uut.IMEM.memory[25] = 32'h00000013;
        uut.IMEM.memory[26] = 32'h00000013;
        uut.IMEM.memory[27] = 32'h0220878B; // MAC   x15, x1, x2
        uut.IMEM.memory[28] = 32'h00000013;
        uut.IMEM.memory[29] = 32'h00000013;
        uut.IMEM.memory[30] = 32'h00000013;
        uut.IMEM.memory[31] = 32'h00000013;
    end
 
    // ========================================================================
    // Main Simulation
    // Timing reference: cycles counted AFTER reset de-asserts.
    //
    //  t=0  : reset de-asserts
    //  t=5  : ADDI x1 (word[0]) completes WB
    //  t=6  : ADDI x2 (word[1]) completes WB
    //  t=8  : ADD  x3 (word[3]) completes WB  (1 NOP gap ? word[3] at WB=t+8)
    //  ...
    //  t=18 : MUL  x12 (word[13]) completes WB
    //  t=22 : MAC1 x13 (word[17]) completes WB ? x13 = 0 (prev accum)
    //  t=32 : MAC3 x15 (word[27]) completes WB ? x15 = 30
    //
    // We check after generous margins; groups 1-5 checked at t?30,
    // group 6 (MAC) checked at t?65 (well after the 3rd MAC settles).
    // ========================================================================
    initial begin
        $dumpfile("riscv_mac_tb.vcd");
        $dumpvars(0, riscv_mac_processor_tb);
 
        // ?? Reset ??????????????????????????????????????????????????????
        reset = 1'b1;
        repeat(5) @(posedge clk);
        @(negedge clk);   // de-assert on falling edge for clean transition
        reset = 1'b0;
 
        $display("");
        $display("????????????????????????????????????????????????????????");
        $display("?     RV32IM + MAC Processor - Self-Checking TB       ?");
        $display("????????????????????????????????????????????????????????");
        $display("  100 MHz clock  |  5-stage pipeline  |  Reset released");
 
        // ?? Group 1 : ADDI ??????????????????????????????????????????????
        // word[0] WB at t?5, word[1] WB at t?6. Check at t=12.
        repeat(12) @(posedge clk);
        $display("");
        $display("?? Group 1: ADDI (Immediate) ??????????????????????????");
        check_reg( 1, 32'd5,  "ADDI x1, x0, 5         ");
        check_reg( 2, 32'd3,  "ADDI x2, x0, 3         ");
 
        // ?? Group 2 : R-Type Arithmetic ?????????????????????????????????
        // word[3..7] WB at t?9..13. Check at t=12+8=20.
        repeat(8) @(posedge clk);
        $display("");
        $display("?? Group 2: R-Type Arithmetic ?????????????????????????");
        check_reg( 3, 32'd8,  "ADD  x3=x1+x2  (5+3=8) ");
        check_reg( 4, 32'd2,  "SUB  x4=x1-x2  (5-3=2) ");
        check_reg( 5, 32'd1,  "AND  x5=x1&x2  (5&3=1) ");
        check_reg( 6, 32'd7,  "OR   x6=x1|x2  (5|3=7) ");
        check_reg( 7, 32'd6,  "XOR  x7=x1^x2  (5^3=6) ");
 
        // ?? Group 3 : Shift & Compare ???????????????????????????????????
        // word[8..10] WB at t?14..16. Check at t=20+5=25.
        repeat(5) @(posedge clk);
        $display("");
        $display("?? Group 3: Shift & Compare ???????????????????????????");
        check_reg( 8, 32'd20, "SLLI x8=x1<<2  (5<<2=20)");
        check_reg( 9, 32'd4,  "SRLI x9=x3>>1  (8>>1=4) ");
        check_reg(10, 32'd1,  "SLT  x10=(x4<x1)=(2<5=1)");
 
        // ?? Group 4 : Load / Store ??????????????????????????????????????
        // SW MEM at t?15; LW WB at t?17. Check at t=25+5=30.
        repeat(5) @(posedge clk);
        $display("");
        $display("?? Group 4: Load / Store ??????????????????????????????");
        check_mem( 0, 32'd5,  "SW   x1?mem[0]  (5?mem)");
        check_reg(11, 32'd5,  "LW   x11?mem[0] (5?mem)");
 
        // ?? Group 5 : MUL ???????????????????????????????????????????????
        // word[13] WB at t?18. Check at t=30+5=35.
        // NOTE: if multiplier.v is pipelined, MUL may capture a stale product.
        //       A FAIL here means multiplier timing needs investigation.
        repeat(5) @(posedge clk);
        $display("");
        $display("?? Group 5: MUL (M-Extension) ?????????????????????????");
        check_reg(12, 32'd15, "MUL  x12=x1*x2  (5*3=15)");
 
        // ?? Group 6 : MAC (Custom Instruction) ??????????????????????????
        // MAC opcode = 0001011 | funct3 = 000 | funct7 = 0000001
        //
        // The mac_unit has a 2-stage internal pipeline:
        //   Stage 1 ? booth_multiplier  (registered, 1-cycle latency)
        //   Stage 2 ? accumulator_adder (registered, 1-cycle latency)
        //
        // When MAC is in EX stage at cycle T:
        //   rd   ? accum_out = OLD accumulator (value BEFORE this MAC)
        //   T+1  : Booth product = 5×3 = 15 (registered)
        //   T+2  : accumulator_adder registers old_accum + 15
        //
        // Writeback values:
        //   x13 ? 0   (accumulator was 0 before MAC #1;  internally: 0?15)
        //   x14 ? 15  (accumulator after MAC #1;         internally: 15?30)
        //   x15 ? 30  (accumulator after MAC #2;         internally: 30?45)
        //
        // MAC #3 (word[27]) WB at t?32. Internal accum settles at t?34.
        // Check at t=35+30=65 - well beyond all pipeline stages.
        repeat(30) @(posedge clk);
        $display("");
        $display("?? Group 6: MAC x3 (opcode=0001011, f3=000, f7=0000001)?");
        $display("   rd receives the accumulator value BEFORE the current MAC.");
        check_reg(13, 32'd0,  "MAC1 x13?accum_init=0   ");
        check_reg(14, 32'd15, "MAC2 x14?accum_post1=15 ");
        check_reg(15, 32'd30, "MAC3 x15?accum_post2=30 ");
 
        // Check the internal accumulator directly
        begin : accum_check
            reg [31:0] acc;
            acc = uut.MAC.adder.sum_out;
            if (acc === 32'd45) begin
                $display("  PASS | Internal accum (3 MACs done)  | %0d (expect 45)", acc);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | Internal accum (3 MACs done)  | %0d (expect 45)", acc);
                fail_count = fail_count + 1;
            end
        end
 
        // ?? Final Summary ????????????????????????????????????????????????
        repeat(5) @(posedge clk);
        $display("");
        $display("????????????????????????????????????????????????????????");
        $display("?  Total tests : %-3d                                  ?",
                 pass_count + fail_count);
        $display("?  Passed      : %-3d                                  ?",
                 pass_count);
        $display("?  Failed      : %-3d                                  ?",
                 fail_count);
        $display("????????????????????????????????????????????????????????");
        $display("");
 
        if (fail_count == 0)
            $display("  >> ALL TESTS PASSED - processor is working correctly.");
        else
            $display("  >> %0d TEST(S) FAILED - open riscv_mac_tb.vcd to debug.", fail_count);
 
        $display("");
        $finish;
    end
 
    // ========================================================================
    // Watchdog - kills simulation if it stalls (e.g. infinite fetch loop)
    // ========================================================================
    initial begin
        #20000; // 20 µs = 2000 cycles at 100 MHz
        $display("  WATCHDOG: simulation exceeded 2000 cycles, force stop.");
        $finish;
    end
 
    // ========================================================================
    // PC Monitor - uncomment to trace every fetch in the Tcl console
    // ========================================================================
    // initial
    //     $monitor("[%5t ns]  PC=0x%08h  reset=%b", $time, pc_out, reset);
 
endmodule
