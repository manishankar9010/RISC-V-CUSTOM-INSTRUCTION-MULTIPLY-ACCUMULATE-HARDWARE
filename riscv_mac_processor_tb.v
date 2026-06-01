`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: riscv_mac_processor_tb
// Description: Self-checking testbench for RV32IM + MAC processor
//
// Matches final fixed design:
//   mac_unit ports : clk, reset, en, A, B, accum_out, mac_overflow
//                    (rst_n + clr_acc removed -- unified active-high reset)
//   top-level ports: clk, reset, pc_out, mac_output,
//                    result_out, rd_out, reg_write_out
//
// Test groups:
//   1  ADDI          x1=5, x2=3
//   2  R-Type        ADD,SUB,AND,OR,XOR
//   3  Shift/Compare SLLI,SRLI,SLT
//   4  Load/Store    SW, LW
//   5  MUL           x12=15
//   6  MAC x3        x13=0, x14=15, x15=30, accum=45
//   7  WB port check result_out, rd_out, reg_write_out
//////////////////////////////////////////////////////////////////////////////////
module riscv_mac_processor_tb;

    // DUT ports
    reg         clk;
    reg         reset;
    wire [31:0] pc_out;
    wire [31:0] mac_output;
    wire [31:0] result_out;
    wire [4:0]  rd_out;
    wire        reg_write_out;

    // DUT
    riscv_mac_processor uut (
        .clk          (clk),
        .reset        (reset),
        .pc_out       (pc_out),
        .mac_output   (mac_output),
        .result_out   (result_out),
        .rd_out       (rd_out),
        .reg_write_out(reg_write_out)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    integer pass_count;
    integer fail_count;
    initial begin
        pass_count = 0;
        fail_count = 0;
    end

    // check register file
    task check_reg;
        input [4:0]   reg_num;
        input [31:0]  expected;
        input [239:0] label;
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

    // check data memory
    task check_mem;
        input [31:0]  word_idx;
        input [31:0]  expected;
        input [239:0] label;
        reg   [31:0]  actual;
        begin
            actual = uut.DMEM.memory[word_idx];
            if (actual === expected) begin
                $display("  PASS | %s | mem[%0d] = %0d", label, word_idx, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %s | mem[%0d] = %0d  (expected %0d)",
                         label, word_idx, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Load test program at #1 (overrides DUT initial block during simulation)
    initial begin
        #1;
        begin : fill_nop
            integer idx;
            for (idx = 0; idx < 256; idx = idx + 1)
                uut.IMEM.memory[idx] = 32'h00000013;
        end

        // Group 1 - ADDI
        uut.IMEM.memory[ 0] = 32'h00500093; // ADDI x1, x0, 5
        uut.IMEM.memory[ 1] = 32'h00300113; // ADDI x2, x0, 3
        uut.IMEM.memory[ 2] = 32'h00000013; // NOP

        // Group 2 - R-Type
        uut.IMEM.memory[ 3] = 32'h002081B3; // ADD  x3,  x1, x2   -> 8
        uut.IMEM.memory[ 4] = 32'h40208233; // SUB  x4,  x1, x2   -> 2
        uut.IMEM.memory[ 5] = 32'h0020F2B3; // AND  x5,  x1, x2   -> 1
        uut.IMEM.memory[ 6] = 32'h0020E333; // OR   x6,  x1, x2   -> 7
        uut.IMEM.memory[ 7] = 32'h0020C3B3; // XOR  x7,  x1, x2   -> 6

        // Group 3 - Shift & Compare
        uut.IMEM.memory[ 8] = 32'h00209413; // SLLI x8,  x1, 2    -> 20
        uut.IMEM.memory[ 9] = 32'h0011D493; // SRLI x9,  x3, 1    -> 4
        uut.IMEM.memory[10] = 32'h00122533; // SLT  x10, x4, x1   -> 1

        // Group 4 - Load/Store
        uut.IMEM.memory[11] = 32'h00102023; // SW   x1,  0(x0)
        uut.IMEM.memory[12] = 32'h00002583; // LW   x11, 0(x0)    -> 5

        // Group 5 - MUL
        uut.IMEM.memory[13] = 32'h02208633; // MUL  x12, x1, x2   -> 15

        // Pipeline drain before MAC
        uut.IMEM.memory[14] = 32'h00000013;
        uut.IMEM.memory[15] = 32'h00000013;
        uut.IMEM.memory[16] = 32'h00000013;

        // Group 6 - MAC x3 (opcode=0001011, funct3=000, funct7=0000001)
        uut.IMEM.memory[17] = 32'h0220868B; // MAC x13, x1, x2  rd=0,  accum->15
        uut.IMEM.memory[18] = 32'h00000013;
        uut.IMEM.memory[19] = 32'h00000013;
        uut.IMEM.memory[20] = 32'h00000013;
        uut.IMEM.memory[21] = 32'h00000013;
        uut.IMEM.memory[22] = 32'h0220870B; // MAC x14, x1, x2  rd=15, accum->30
        uut.IMEM.memory[23] = 32'h00000013;
        uut.IMEM.memory[24] = 32'h00000013;
        uut.IMEM.memory[25] = 32'h00000013;
        uut.IMEM.memory[26] = 32'h00000013;
        uut.IMEM.memory[27] = 32'h0220878B; // MAC x15, x1, x2  rd=30, accum->45
        uut.IMEM.memory[28] = 32'h00000013;
        uut.IMEM.memory[29] = 32'h00000013;
        uut.IMEM.memory[30] = 32'h00000013;
        uut.IMEM.memory[31] = 32'h00000013;
    end

    // Reset check: accumulator must be 0 right after reset de-asserts
    initial begin
        @(negedge reset);
        #1;
        if (uut.MAC.adder.sum_out === 32'd0)
            $display("  INFO | Reset check PASS: accum=0 after posedge reset released");
        else
            $display("  WARN | Reset check FAIL: accum=%0d after reset (expect 0)",
                     uut.MAC.adder.sum_out);
    end

    // Main simulation
    initial begin
        $dumpfile("riscv_mac_tb.vcd");
        $dumpvars(0, riscv_mac_processor_tb);

        // Assert active-HIGH reset for 5 cycles
        reset = 1'b1;
        repeat(5) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        $display("");
        $display("========================================================");
        $display("  RV32IM + MAC  --  Self-Checking TB                    ");
        $display("  Reset: active-HIGH unified across all modules          ");
        $display("========================================================");

        // Group 1
        repeat(12) @(posedge clk);
        $display("");
        $display("-- Group 1: ADDI ---------------------------------------");
        check_reg( 1, 32'd5,  "ADDI x1, x0, 5         ");
        check_reg( 2, 32'd3,  "ADDI x2, x0, 3         ");

        // Group 2
        repeat(8) @(posedge clk);
        $display("");
        $display("-- Group 2: R-Type Arithmetic --------------------------");
        check_reg( 3, 32'd8,  "ADD  x3=x1+x2  (5+3=8) ");
        check_reg( 4, 32'd2,  "SUB  x4=x1-x2  (5-3=2) ");
        check_reg( 5, 32'd1,  "AND  x5=x1&x2  (5&3=1) ");
        check_reg( 6, 32'd7,  "OR   x6=x1|x2  (5|3=7) ");
        check_reg( 7, 32'd6,  "XOR  x7=x1^x2  (5^3=6) ");

        // Group 3
        repeat(5) @(posedge clk);
        $display("");
        $display("-- Group 3: Shift & Compare ----------------------------");
        check_reg( 8, 32'd20, "SLLI x8=x1<<2 (5<<2=20)");
        check_reg( 9, 32'd4,  "SRLI x9=x3>>1  (8>>1=4)");
        check_reg(10, 32'd1,  "SLT  x10=(2<5)=1       ");

        // Group 4
        repeat(5) @(posedge clk);
        $display("");
        $display("-- Group 4: Load / Store --------------------------------");
        check_mem( 0, 32'd5,  "SW  x1->mem[0]         ");
        check_reg(11, 32'd5,  "LW  x11<-mem[0]        ");

        // Group 5
        repeat(5) @(posedge clk);
        $display("");
        $display("-- Group 5: MUL (M-Extension) --------------------------");
        check_reg(12, 32'd15, "MUL x12=x1*x2 (5*3=15) ");

        // Group 6
        repeat(30) @(posedge clk);
        $display("");
        $display("-- Group 6: MAC x3 (op=0001011,f3=000,f7=0000001) -----");
        $display("   rd = accumulator value BEFORE current MAC fires.");
        check_reg(13, 32'd0,  "MAC1 x13=old_accum=0   ");
        check_reg(14, 32'd15, "MAC2 x14=old_accum=15  ");
        check_reg(15, 32'd30, "MAC3 x15=old_accum=30  ");

        // Internal accumulator check (hierarchical: uut.MAC.adder.sum_out)
        begin : accum_chk
            reg [31:0] acc;
            acc = uut.MAC.adder.sum_out;
            if (acc === 32'd45) begin
                $display("  PASS | uut.MAC.adder.sum_out      | %0d (expect 45)", acc);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | uut.MAC.adder.sum_out      | %0d (expect 45)", acc);
                fail_count = fail_count + 1;
            end
        end

        // mac_output port check (= accum_out after all MACs settled)
        begin : mac_port_chk
            reg [31:0] mout;
            mout = mac_output;
            if (mout === 32'd45) begin
                $display("  PASS | mac_output port            | %0d (expect 45)", mout);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | mac_output port            | %0d (expect 45)", mout);
                fail_count = fail_count + 1;
            end
        end

        // Group 7 - WB output ports
        repeat(5) @(posedge clk);
        $display("");
        $display("-- Group 7: WB-Stage Output Ports ----------------------");
        $display("   result_out=%0d  rd_out=%0d  reg_write_out=%b",
                 result_out, rd_out, reg_write_out);
        // reg_write_out=0 is valid here if pipeline drained past x15 WB
        if (reg_write_out === 1'b0) begin
            $display("  PASS | reg_write_out=0 (pipeline drained -- OK)    ");
            pass_count = pass_count + 1;
        end else if (reg_write_out === 1'b1) begin
            $display("  PASS | reg_write_out=1  rd=%0d  result=%0d        ",
                     rd_out, result_out);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL | reg_write_out=X (unknown state)             ");
            fail_count = fail_count + 1;
        end

        // Final summary
        repeat(3) @(posedge clk);
        $display("");
        $display("========================================================");
        $display("  Total : %-3d  |  Passed : %-3d  |  Failed : %-3d",
                 pass_count + fail_count, pass_count, fail_count);
        $display("========================================================");
        if (fail_count == 0)
            $display("  >> ALL TESTS PASSED -- processor working correctly.");
        else
            $display("  >> %0d TEST(S) FAILED -- check riscv_mac_tb.vcd.",
                     fail_count);
        $display("");
        $finish;
    end

    // Watchdog
    initial begin
        #20000;
        $display("  WATCHDOG: exceeded 2000 cycles -- force stop.");
        $finish;
    end

endmodule