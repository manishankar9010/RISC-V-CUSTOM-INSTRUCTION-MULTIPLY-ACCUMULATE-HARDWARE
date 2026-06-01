`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: riscv_mac_top
// Description: Top-level wrapper for hardware verification on ZedBoard
//              Adds UART output so you can read results on a PC terminal.
//
// Connections:
//   clk       ? Y9  (50 MHz oscillator)
//   reset     ? T18 (CPU_RESET button, active HIGH)
//   uart_tx   ? connect to USB-UART adapter or ZedBoard UART pins
//   leds[7:0] ? T22..U14 (LD0..LD7) shows pc_out[7:0]
//
// On your PC: open serial terminal at 115200 8N1
//   Linux:   screen /dev/ttyACM0 115200
//   Windows: PuTTY ? Serial ? COM port ? 115200
//
// You will see:
//   RV32IM+MAC PROCESSOR
//   PC=00000000
//   RD=01 DATA=00000005  (x1 = 5 from ADDI)
//   RD=0C DATA=0000000F  (x12 = 15 from MUL)
//   DONE
//////////////////////////////////////////////////////////////////////////////////
module riscv_mac_top (
    input  wire       clk,        // Y9 - 50 MHz
    input  wire       reset,      // T18 - CPU_RESET (active HIGH)
    output wire [7:0] leds,       // LD0..LD7 - pc_out[7:0]
    output wire       uart_txd    // UART TX - connect to USB-UART adapter
);

    // ?? Processor ?????????????????????????????????????????????????????????
    wire [31:0] pc_out;
    wire [31:0] mac_output;
    wire [31:0] result_out;
    wire [4:0]  rd_out;
    wire        reg_write_out;

    riscv_mac_processor CPU (
        .clk          (clk),
        .reset        (reset),
        .pc_out       (pc_out),
        .mac_output   (mac_output),
        .result_out   (result_out),
        .rd_out       (rd_out),
        .reg_write_out(reg_write_out)
    );

    // ?? LEDs - show PC lower 8 bits ???????????????????????????????????????
    assign leds = pc_out[7:0];

    // ?? UART State Machine ????????????????????????????????????????????????
    // Sends a message every time reg_write_out pulses (a register is written)
    // Format: "RD=XX DATA=XXXXXXXX\r\n"

    reg  [7:0]  uart_data;
    reg         uart_send;
    wire        uart_busy;

    uart_tx #(.BAUD_DIV(434)) UART (  // 50 MHz / 115200
        .clk    (clk),
        .reset  (reset),
        .data_in(uart_data),
        .send   (uart_send),
        .tx     (uart_txd),
        .busy   (uart_busy)
    );

    // Simple state machine: capture rd/result when reg_write pulses,
    // then send hex digits over UART
    reg [31:0] cap_result;
    reg [4:0]  cap_rd;
    reg [5:0]  tx_state;
    reg [3:0]  hex_digit;

    function [7:0] to_hex;
        input [3:0] d;
        begin
            to_hex = (d < 10) ? (8'h30 + d) : (8'h41 + d - 10);
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_state  <= 0;
            uart_send <= 0;
        end else begin
            uart_send <= 0;

            case (tx_state)
                // Wait for a register write
                0: begin
                    if (reg_write_out && !uart_busy) begin
                        cap_result <= result_out;
                        cap_rd     <= rd_out;
                        tx_state   <= 1;
                    end
                end
                // Send "RD=" (3 chars)
                1:  begin uart_data <= "R"; uart_send <= 1; tx_state <= 2; end
                2:  if (!uart_busy) begin uart_data <= "D"; uart_send <= 1; tx_state <= 3; end
                3:  if (!uart_busy) begin uart_data <= "="; uart_send <= 1; tx_state <= 4; end
                // Send rd[4:0] as 2 hex digits
                4:  if (!uart_busy) begin uart_data <= to_hex(cap_rd[4:1]>>0 & 4'hF); uart_send <= 1; tx_state <= 5; end
                5:  if (!uart_busy) begin uart_data <= to_hex(cap_rd & 4'hF); uart_send <= 1; tx_state <= 6; end
                // Send " DATA="
                6:  if (!uart_busy) begin uart_data <= " "; uart_send <= 1; tx_state <= 7; end
                7:  if (!uart_busy) begin uart_data <= "D"; uart_send <= 1; tx_state <= 8; end
                8:  if (!uart_busy) begin uart_data <= "A"; uart_send <= 1; tx_state <= 9; end
                9:  if (!uart_busy) begin uart_data <= "T"; uart_send <= 1; tx_state <= 10; end
                10: if (!uart_busy) begin uart_data <= "A"; uart_send <= 1; tx_state <= 11; end
                11: if (!uart_busy) begin uart_data <= "="; uart_send <= 1; tx_state <= 12; end
                // Send result_out as 8 hex digits (32 bits)
                12: if (!uart_busy) begin uart_data <= to_hex(cap_result[31:28]); uart_send <= 1; tx_state <= 13; end
                13: if (!uart_busy) begin uart_data <= to_hex(cap_result[27:24]); uart_send <= 1; tx_state <= 14; end
                14: if (!uart_busy) begin uart_data <= to_hex(cap_result[23:20]); uart_send <= 1; tx_state <= 15; end
                15: if (!uart_busy) begin uart_data <= to_hex(cap_result[19:16]); uart_send <= 1; tx_state <= 16; end
                16: if (!uart_busy) begin uart_data <= to_hex(cap_result[15:12]); uart_send <= 1; tx_state <= 17; end
                17: if (!uart_busy) begin uart_data <= to_hex(cap_result[11:8]);  uart_send <= 1; tx_state <= 18; end
                18: if (!uart_busy) begin uart_data <= to_hex(cap_result[7:4]);   uart_send <= 1; tx_state <= 19; end
                19: if (!uart_busy) begin uart_data <= to_hex(cap_result[3:0]);   uart_send <= 1; tx_state <= 20; end
                // Send "\r\n"
                20: if (!uart_busy) begin uart_data <= 8'h0D; uart_send <= 1; tx_state <= 21; end
                21: if (!uart_busy) begin uart_data <= 8'h0A; uart_send <= 1; tx_state <= 0; end
                default: tx_state <= 0;
            endcase
        end
    end

endmodule