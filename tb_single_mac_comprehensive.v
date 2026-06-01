`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.03.2026 05:48:40
// Design Name: 
// Module Name: tb_single_mac_comprehensive
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

module tb_single_mac_comprehensive;

parameter CLK_PERIOD = 10;
parameter TIMEOUT    = 20000;

reg clk;
reg reset;
reg [31:0] mem_read_data_in;

wire [31:0] mem_address;
wire [31:0] mem_write_data;
wire mem_write_enable;
wire mem_read_enable;

wire [31:0] current_pc;
wire [31:0] instruction;

wire [47:0] mac_accumulator;
wire mac_overflow;

///////////////////////////////////////////////////////////////
// DUT
///////////////////////////////////////////////////////////////

top_riscv_mac_single dut(
    .clk(clk),
    .reset(reset),

    .mem_address(mem_address),
    .mem_write_data(mem_write_data),
    .mem_write_enable(mem_write_enable),
    .mem_read_enable(mem_read_enable),
    .mem_read_data_in(mem_read_data_in),

    .current_pc(current_pc),
    .instruction(instruction),

    .mac_accumulator(mac_accumulator),
    .mac_overflow(mac_overflow)
);

///////////////////////////////////////////////////////////////
// CLOCK
///////////////////////////////////////////////////////////////

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

///////////////////////////////////////////////////////////////

integer pass_cnt;
integer fail_cnt;
integer test_num;

///////////////////////////////////////////////////////////////
// CLEAR INSTRUCTION MEMORY
///////////////////////////////////////////////////////////////

task clear_imem;
integer i;
begin
for(i=0;i<256;i=i+1)
    dut.imem.memory[i] = 8'h00;
end
endtask

///////////////////////////////////////////////////////////////
// LOAD INSTRUCTION
///////////////////////////////////////////////////////////////

task load_instr;
input [31:0] addr;
input [31:0] instr;
begin
dut.imem.memory[addr]   = instr[7:0];
dut.imem.memory[addr+1] = instr[15:8];
dut.imem.memory[addr+2] = instr[23:16];
dut.imem.memory[addr+3] = instr[31:24];
end
endtask

///////////////////////////////////////////////////////////////

task tick;
input integer n;
integer i;
begin
for(i=0;i<n;i=i+1)
@(posedge clk);
#1;
end
endtask

///////////////////////////////////////////////////////////////

task do_reset;
begin
reset = 1;
tick(5);
reset = 0;
#1;
end
endtask

///////////////////////////////////////////////////////////////

task halt_at;
input [31:0] addr;
begin
load_instr(addr,32'h0000006F); // JAL x0,0
end
endtask

///////////////////////////////////////////////////////////////

task check_reg;

input [4:0] regid;
input [31:0] expected;
input [200:0] name;

reg [31:0] actual;

begin

actual = dut.rf.registers[regid];
test_num = test_num + 1;

if(actual === expected)
begin
$display("[PASS] %s -> %d",name,actual);
pass_cnt = pass_cnt + 1;
end
else
begin
$display("[FAIL] %s expected %d got %d",name,expected,actual);
fail_cnt = fail_cnt + 1;
end

end
endtask

///////////////////////////////////////////////////////////////
// MAIN TEST
///////////////////////////////////////////////////////////////

initial begin

$display("=================================================");
$display("GARUDA RISC-V MAC Processor Verification");
$display("=================================================");

pass_cnt = 0;
fail_cnt = 0;
test_num = 0;

mem_read_data_in = 0;

///////////////////////////////////////////////////////////////
// GROUP 1 : RV32I Arithmetic
///////////////////////////////////////////////////////////////

$display("\n--- GROUP 1: RV32I Arithmetic ---");

clear_imem();
do_reset();

load_instr(0 ,32'h00F00093);  // addi x1,x0,15
load_instr(4 ,32'h01400113);  // addi x2,x0,20
load_instr(8 ,32'h002081B3);  // add x3,x1,x2

halt_at(12);

tick(40);

check_reg(3,35,"ADD 15+20");

///////////////////////////////////////////////////////////////
// GROUP 2 : RV32M Multiply
///////////////////////////////////////////////////////////////

$display("\n--- GROUP 2: Multiply ---");

clear_imem();
do_reset();

load_instr(0 ,32'h00700093);  // x1=7
load_instr(4 ,32'h00900113);  // x2=9
load_instr(8 ,32'h022081B3);  // mul x3,x1,x2

halt_at(12);

tick(40);

check_reg(3,63,"MUL 7*9");

///////////////////////////////////////////////////////////////
// GROUP 3 : MAC BASIC
///////////////////////////////////////////////////////////////

$display("\n--- GROUP 3: MAC Basic ---");

clear_imem();
do_reset();

load_instr(0 ,32'h0000000B);  // MACCLEAR

load_instr(4 ,32'h00500093);  // x1=5
load_instr(8 ,32'h00600113);  // x2=6

load_instr(12,32'h0020900B);  // MAC x1,x2

load_instr(16,32'h0001218B);  // MACREAD x3

halt_at(20);

tick(80);

check_reg(3,30,"MAC 5*6");

///////////////////////////////////////////////////////////////
// GROUP 4 : MAC ACCUMULATION
///////////////////////////////////////////////////////////////

$display("\n--- GROUP 4: MAC Accumulation ---");

clear_imem();
do_reset();

load_instr(0 ,32'h0000000B);  // MACCLEAR

load_instr(4 ,32'h00200093);  // x1=2
load_instr(8 ,32'h00300113);  // x2=3
load_instr(12,32'h0020900B);  // MAC

load_instr(16,32'h00400093);  // x1=4
load_instr(20,32'h00500113);  // x2=5
load_instr(24,32'h0020900B);  // MAC

load_instr(28,32'h00600093);  // x1=6
load_instr(32,32'h00700113);  // x2=7
load_instr(36,32'h0020900B);  // MAC

load_instr(40,32'h0001218B);  // MACREAD x3

halt_at(44);

tick(120);

check_reg(3,68,"MAC accumulation");

///////////////////////////////////////////////////////////////
// GROUP 5 : NEGATIVE MAC
///////////////////////////////////////////////////////////////

$display("\n--- GROUP 5: Negative MAC ---");

clear_imem();
do_reset();

load_instr(0 ,32'h0000000B);  // MACCLEAR

load_instr(4 ,32'h00500093);  // x1=5
load_instr(8 ,32'h00600113);  // x2=6

load_instr(12,32'h0020900B);  // MAC
load_instr(16,32'h0020C00B);  // MACNMAC

load_instr(20,32'h0001218B);  // MACREAD x3

halt_at(24);

tick(100);

check_reg(3,0,"MAC - MAC");

///////////////////////////////////////////////////////////////
// FINAL REPORT
///////////////////////////////////////////////////////////////

$display("\n=================================================");
$display("FINAL TEST SUMMARY");
$display("PASSED : %d",pass_cnt);
$display("FAILED : %d",fail_cnt);
$display("TOTAL  : %d",pass_cnt+fail_cnt);

if(fail_cnt==0)
$display(">>> ALL TESTS PASSED - GARUDA VERIFIED <<<");
else
$display(">>> %d TESTS FAILED <<<",fail_cnt);

$display("=================================================");

$finish;

end

///////////////////////////////////////////////////////////////
// WATCHDOG
///////////////////////////////////////////////////////////////

initial begin
#(CLK_PERIOD*TIMEOUT);
$display("WATCHDOG TIMEOUT");
$finish;
end

endmodule
