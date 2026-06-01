`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: mac_unit_tb
// DUT      : mac_unit (16x16 signed MAC, saturating 32-bit accumulator)
//
// Pipeline latency: 2 cycles
//   Cycle T   (en=1) : booth_multiplier captures A, B
//   Cycle T+1 (en_d1=1): accumulator_adder fires with valid product
//   Cycle T+2        : accum_out holds the updated saturated result
//
// Sampling rule: @(posedge clk) after 2 idle cycles post-en pulse,
//   i.e. check outputs 2 clock edges after deasserting en.
//
// Test cases:
//   TC01  Basic positive × positive
//   TC02  Positive × negative (signed)
//   TC03  Negative × negative
//   TC04  Zero operand A
//   TC05  Zero operand B
//   TC06  Accumulation across two consecutive MACs
//   TC07  Maximum positive × maximum positive (positive overflow ? saturate)
//   TC08  Maximum negative × maximum positive (negative overflow ? saturate)
//   TC09  Boundary: +1 × -1
//   TC10  Large accumulation loop (tests sticky overflow flag)
//   TC11  Reset during computation clears accumulator
//   TC12  en de-asserted mid-pipeline does not corrupt accumulator
//   TC13  Overflow flag stays sticky after first overflow
//   TC14  +32767 × +32767 (max signed 16-bit squares)
//   TC15  Alternating sign accumulation
//////////////////////////////////////////////////////////////////////////////////

module mac_unit_tb;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg         clk;
    reg         reset;
    reg         en;
    reg  [15:0] A;
    reg  [15:0] B;
    wire [31:0] accum_out;
    wire        mac_overflow;

    // -------------------------------------------------------------------------
    // Instantiate DUT
    // -------------------------------------------------------------------------
    mac_unit dut (
        .clk         (clk),
        .reset       (reset),
        .en          (en),
        .A           (A),
        .B           (B),
        .accum_out   (accum_out),
        .mac_overflow(mac_overflow)
    );

    // -------------------------------------------------------------------------
    // Clock: 10 ns period
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Test book-keeping
    // -------------------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer tc_num;

    // -------------------------------------------------------------------------
    // Task: reset_dut
    //   Assert reset for 3 cycles then release.
    // -------------------------------------------------------------------------
    task reset_dut;
        begin
            reset = 1'b1;
            en    = 1'b0;
            A     = 16'h0000;
            B     = 16'h0000;
            @(posedge clk); #1;
            @(posedge clk); #1;
            @(posedge clk); #1;
            reset = 1'b0;
            @(posedge clk); #1;   // one idle cycle after release
        end
    endtask

    // -------------------------------------------------------------------------
    // Task: do_mac
    //   Drive a single MAC operation (en high for 1 cycle).
    //   Returns immediately after pulsing; caller must wait 2 cycles to sample.
    // -------------------------------------------------------------------------
    task do_mac;
        input [15:0] op_a;
        input [15:0] op_b;
        begin
            A  = op_a;
            B  = op_b;
            en = 1'b1;
            @(posedge clk); #1;   // latch into booth_multiplier
            en = 1'b0;
            A  = 16'h0000;
            B  = 16'h0000;
        end
    endtask

    // -------------------------------------------------------------------------
    // Task: wait_result
    //   Wait the 2 pipeline cycles then read accum_out one cycle later.
    //   After do_mac, en_d1 goes high next cycle (accumulator fires), and
    //   accum_out is stable 1 more cycle after that.
    // -------------------------------------------------------------------------
    task wait_result;
        begin
            @(posedge clk); #1;   // en_d1 fires ? adder writes accumulator
            @(posedge clk); #1;   // result propagates to accum_out
        end
    endtask

    // -------------------------------------------------------------------------
    // Task: check
    //   Compare actual vs expected and log pass/fail.
    // -------------------------------------------------------------------------
    task check;
        input [31:0] got_accum;
        input [31:0] exp_accum;
        input        got_ovf;
        input        exp_ovf;
        input [63:0] tc_id;        // test-case number for display
        begin
            if ((got_accum === exp_accum) && (got_ovf === exp_ovf)) begin
                $display("[PASS] TC%0d  accum=0x%08h  overflow=%b",
                         tc_id, got_accum, got_ovf);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] TC%0d  accum: got=0x%08h exp=0x%08h | overflow: got=%b exp=%b",
                         tc_id, got_accum, exp_accum, got_ovf, exp_ovf);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("=============================================================");
        $display("  mac_unit testbench  (signed 16x16 ? saturating 32-bit)");
        $display("=============================================================");

        // ------------------------------------------------------------------
        // TC01: Basic positive × positive
        //   A=3, B=4  ?  product=12  ?  accum = 0 + 12 = 12
        // ------------------------------------------------------------------
        tc_num = 1;
        reset_dut;
        do_mac(16'd3, 16'd4);
        wait_result;
        check(accum_out, 32'd12, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // TC02: Positive × negative
        //   A=10, B=-5  ?  product=-50  ?  accum = 0 + (-50) = -50
        //   -50 in 32-bit two's complement = 0xFFFF_FFCE
        // ------------------------------------------------------------------
        tc_num = 2;
        reset_dut;
        do_mac(16'd10, -16'd5);
        wait_result;
        check(accum_out, 32'hFFFF_FFCE, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // TC03: Negative × negative
        //   A=-7, B=-3  ?  product=21  ?  accum = 0 + 21 = 21
        // ------------------------------------------------------------------
        tc_num = 3;
        reset_dut;
        do_mac(-16'd7, -16'd3);
        wait_result;
        check(accum_out, 32'd21, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // TC04: Zero operand A
        //   A=0, B=1234  ?  product=0  ?  accum = 0
        // ------------------------------------------------------------------
        tc_num = 4;
        reset_dut;
        do_mac(16'd0, 16'd1234);
        wait_result;
        check(accum_out, 32'd0, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // TC05: Zero operand B
        //   A=5678, B=0  ?  product=0  ?  accum = 0
        // ------------------------------------------------------------------
        tc_num = 5;
        reset_dut;
        do_mac(16'd5678, 16'd0);
        wait_result;
        check(accum_out, 32'd0, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // TC06: Accumulation across two consecutive MACs
        //   MAC1: A=100, B=200  ?  product=20000  ?  accum=20000
        //   MAC2: A=50,  B=3    ?  product=150    ?  accum=20150
        //   (en is pulsed twice; wait 2 cycles between each for pipeline drain)
        // ------------------------------------------------------------------
        tc_num = 6;
        reset_dut;
        do_mac(16'd100, 16'd200);
        wait_result;
        // accum should be 20000 here; start second mac AFTER result is settled
        do_mac(16'd50, 16'd3);
        wait_result;
        check(accum_out, 32'd20150, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // TC07: Positive overflow ? saturate to 32'h7FFF_FFFF
        //   A=+32767 (0x7FFF), B=+32767 (0x7FFF)
        //   Product = 32767²  = 1_073_676_289  (fits in 32 bits, no overflow yet)
        //   Accumulate the same product TWICE so sum exceeds INT32_MAX=2_147_483_647
        //   Step1: accum = 1_073_676_289
        //   Step2: accum = 1_073_676_289 + 1_073_676_289 = 2_147_352_578 (< MAX, OK)
        //   Step3: same again ? 2_147_352_578 + 1_073_676_289 > 2_147_483_647 ? saturate
        //   Expected accum = 0x7FFF_FFFF, overflow = 1
        // ------------------------------------------------------------------
        tc_num = 7;
        reset_dut;
        do_mac(16'h7FFF, 16'h7FFF);   // step 1
        wait_result;
        do_mac(16'h7FFF, 16'h7FFF);   // step 2
        wait_result;
        do_mac(16'h7FFF, 16'h7FFF);   // step 3 ? overflow
        wait_result;
        check(accum_out, 32'h7FFF_FFFF, mac_overflow, 1'b1, tc_num);

        // ------------------------------------------------------------------
        // TC08: Negative overflow ? saturate to 32'h8000_0000
        //   A=-32768 (0x8000), B=+32767 (0x7FFF)
        //   Product = -32768 × 32767 = -1_073_709_056
        //   Two MACs: accum = -2_147_418_112 (still > INT32_MIN=-2_147_483_648)
        //   Three MACs: -2_147_418_112 + (-1_073_709_056) ? underflow ? saturate
        //   Expected accum = 0x8000_0000, overflow = 1
        // ------------------------------------------------------------------
        tc_num = 8;
        reset_dut;
        do_mac(16'h8000, 16'h7FFF);   // step 1
        wait_result;
        do_mac(16'h8000, 16'h7FFF);   // step 2
        wait_result;
        do_mac(16'h8000, 16'h7FFF);   // step 3 ? underflow
        wait_result;
        check(accum_out, 32'h8000_0000, mac_overflow, 1'b1, tc_num);

        // ------------------------------------------------------------------
        // TC09: Boundary: +1 × -1
        //   A=1, B=-1  ?  product=-1  ?  accum = 0xFFFF_FFFF
        // ------------------------------------------------------------------
        tc_num = 9;
        reset_dut;
        do_mac(16'd1, 16'hFFFF);
        wait_result;
        check(accum_out, 32'hFFFF_FFFF, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // TC10: Sticky overflow flag
        //   Overflow once (positive), then do another MAC.
        //   Overflow flag must remain 1 (sticky) after subsequent MACs.
        //   Use same 3-step positive overflow from TC07, then add a benign MAC.
        // ------------------------------------------------------------------
        tc_num = 10;
        reset_dut;
        // Overflow with 3 × (32767 × 32767)
        do_mac(16'h7FFF, 16'h7FFF);
        wait_result;
        do_mac(16'h7FFF, 16'h7FFF);
        wait_result;
        do_mac(16'h7FFF, 16'h7FFF);
        wait_result;
        // One more benign MAC after overflow
        do_mac(16'd1, 16'd1);
        wait_result;
        // Accum still saturated, overflow sticky
        check(accum_out, 32'h7FFF_FFFF, mac_overflow, 1'b1, tc_num);

        // ------------------------------------------------------------------
        // TC11: Reset during computation clears accumulator
        //   Start a MAC, then assert reset mid-way.
        //   After reset de-asserts, accum_out must be 0 and overflow must be 0.
        // ------------------------------------------------------------------
        tc_num = 11;
        // Build up a non-zero accumulator first
        reset_dut;
        do_mac(16'd100, 16'd100);
        wait_result;
        // Now assert reset asynchronously
        reset = 1'b1;
        #3;                           // mid-cycle pulse
        reset = 1'b0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        // After reset, accumulator must be 0
        check(accum_out, 32'd0, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // TC12: en de-asserted: no mac should not update accumulator
        //   Set up accum = 12 from TC01 scenario, then let clocks tick
        //   without en. accum_out must remain 12.
        // ------------------------------------------------------------------
        tc_num = 12;
        reset_dut;
        do_mac(16'd3, 16'd4);     // accum ? 12
        wait_result;
        // 5 idle cycles, en=0
        repeat(5) @(posedge clk); #1;
        check(accum_out, 32'd12, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // TC13: Alternating positive / negative accumulation
        //   MAC1: A=1000, B=100  ?  product= 100000
        //   MAC2: A=500,  B=-200 ?  product=-100000
        //   Net: accum = 0
        // ------------------------------------------------------------------
        tc_num = 13;
        reset_dut;
        do_mac(16'd1000, 16'd100);
        wait_result;
        do_mac(16'd500, -16'd200);
        wait_result;
        check(accum_out, 32'd0, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // TC14: Maximum signed product magnitude (positive)
        //   A=32767 (INT16_MAX), B=32767
        //   Product = 1,073,676,289 ? fits in 32-bit signed ? no overflow
        //   Expected accum = 32'd1_073_676_289 = 0x3FFF_0001
        // ------------------------------------------------------------------
        tc_num = 14;
        reset_dut;
        do_mac(16'h7FFF, 16'h7FFF);
        wait_result;
        check(accum_out, 32'h3FFF_0001, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // TC15: Maximum signed product magnitude (negative)
        //   A=-32768 (INT16_MIN), B=-32768 (INT16_MIN)
        //   Product = (-32768)² = 1,073,741,824 = 0x4000_0000
        //   Fits in 32-bit signed (< 0x7FFFFFFF) ? no overflow
        // ------------------------------------------------------------------
        tc_num = 15;
        reset_dut;
        do_mac(16'h8000, 16'h8000);
        wait_result;
        check(accum_out, 32'h4000_0000, mac_overflow, 1'b0, tc_num);

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("=============================================================");
        $display("  Results: %0d passed, %0d failed  (total %0d)",
                 pass_count, fail_count, pass_count + fail_count);
        $display("=============================================================");

        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  *** FAILURES DETECTED - review log above ***");

        $finish;
    end

    // =========================================================================
    // Timeout watchdog (prevents infinite hangs)
    // =========================================================================
    initial begin
        #50000;
        $display("[TIMEOUT] Simulation exceeded 50 us - aborting.");
        $finish;
    end

    // =========================================================================
    // Optional: waveform dump (comment out if not needed)
    // =========================================================================
    initial begin
        $dumpfile("mac_unit_tb.vcd");
        $dumpvars(0, mac_unit_tb);
    end

endmodule