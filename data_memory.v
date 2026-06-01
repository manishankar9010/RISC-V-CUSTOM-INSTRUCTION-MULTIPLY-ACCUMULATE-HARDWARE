`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: data_memory
//
// SYNTHESIS FIX:
//   Added (* ram_style = "distributed" *) attribute to the memory array.
//
//   ROOT CAUSE OF HANG: 256x32 = 8,192 bits exceeds Vivado's BRAM threshold
//   (~1Kbit), so without this attribute Vivado tries to infer a BRAM.
//   However BRAMs have SYNCHRONOUS read ports only. The always @(*) async read
//   below is INCOMPATIBLE with BRAM. Vivado then spends 30+ minutes trying
//   every possible workaround (output register insertion, read-first / write-first
//   mode switching) and eventually gives up or hangs.
//
//   FIX: Force distributed (LUT) RAM which natively supports async reads.
//   Cost: ~256 LUTs used for the memory array instead of 1 BRAM tile.
//   Benefit: Synthesis completes in seconds, async read works correctly.
//////////////////////////////////////////////////////////////////////////////////
module data_memory (
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [2:0]  funct3,
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data
);
    // FIX: force distributed RAM - compatible with async always @(*) read below
    (* ram_style = "distributed" *) reg [31:0] memory [0:255];

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            memory[i] = 32'h00000000;
    end

    wire [7:0] word_addr = address[9:2];

    // Synchronous write
    always @(posedge clk) begin
        if (mem_write) begin
            case (funct3)
                3'b000: begin // SB
                    case (address[1:0])
                        2'b00: memory[word_addr][7:0]   <= write_data[7:0];
                        2'b01: memory[word_addr][15:8]  <= write_data[7:0];
                        2'b10: memory[word_addr][23:16] <= write_data[7:0];
                        2'b11: memory[word_addr][31:24] <= write_data[7:0];
                    endcase
                end
                3'b001: begin // SH
                    case (address[1])
                        1'b0: memory[word_addr][15:0]  <= write_data[15:0];
                        1'b1: memory[word_addr][31:16] <= write_data[15:0];
                    endcase
                end
                3'b010: memory[word_addr] <= write_data; // SW
                default: memory[word_addr] <= write_data;
            endcase
        end
    end

    // Asynchronous read - valid ONLY with distributed RAM (LUT-based)
    always @(*) begin
        if (mem_read) begin
            case (funct3)
                3'b000: read_data = {{24{memory[word_addr][7]}},  memory[word_addr][7:0]};   // LB
                3'b001: read_data = {{16{memory[word_addr][15]}}, memory[word_addr][15:0]};  // LH
                3'b010: read_data = memory[word_addr];                                        // LW
                3'b100: read_data = {24'h0, memory[word_addr][7:0]};                         // LBU
                3'b101: read_data = {16'h0, memory[word_addr][15:0]};                        // LHU
                default: read_data = memory[word_addr];
            endcase
        end else begin
            read_data = 32'h00000000;
        end
    end
endmodule