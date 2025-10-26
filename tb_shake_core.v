`timescale 1ns/1ps

`include "shake_core.v"
module tb_shake_core;
    // ------------------------------------------------------------------------
    // DUT I/O
    // ------------------------------------------------------------------------
    reg clk, reset, start;
    reg in_valid, is_last;
    reg [63:0] in_data;
    reg [2:0] byte_num;
    wire ready;
    wire out_valid;
    wire [511:0] out_data;
    reg out_ready;
    wire done;

    // ------------------------------------------------------------------------
    // Instantiate DUT (SHAKE core)
    // ------------------------------------------------------------------------
    shake_core #(
        .RATE_BITS(1344),   // SHAKE128
        .SUFFIX(8'h1F),
        .OUT_BITS(512)
    ) uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .in_valid(in_valid),
        .in_data(in_data),
        .is_last(is_last),
        .byte_num(byte_num),
        .ready(ready),
        .out_valid(out_valid),
        .out_data(out_data),
        .out_ready(out_ready),
        .done(done)
    );

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // ------------------------------------------------------------------------
    // Waveform Dump
    // ------------------------------------------------------------------------
    initial begin
        // VCD (Value Change Dump) file for GTKWave / Icarus Verilog
        $dumpfile("shake_core_waveform.vcd");  // file name
        $dumpvars(0, tb_shake_core);           // dump all signals in testbench + DUT
    end

    // ------------------------------------------------------------------------
    // Test Sequence
    // ------------------------------------------------------------------------
    initial begin
        $display("=== SHAKE Core FSM Test ===");

        // Initialize signals
        reset     = 1;
        start     = 0;
        in_valid  = 0;
        in_data   = 0;
        is_last   = 0;
        byte_num  = 0;
        out_ready = 0;
        #20;
        reset = 0;

        // Start SHAKE absorption
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Send first 64-bit input
        // wait (ready);
        @(posedge clk);
        in_data  = 64'hAABBCCDDEEFF1122;
        in_valid = 1;
        is_last  = 0;
        byte_num = 0;

        repeat (2)@(posedge clk);
        in_valid = 0;

        repeat (26) @(posedge clk);
        // wait (ready);
        // @(posedge clk);
        in_data  = 64'hABADBABEFF1122;
        in_valid = 1;
        is_last  = 0;
        byte_num = 0;

        repeat (2)@(posedge clk);
        in_valid = 0;

        // Send second input (last block)
        // repeat (5) @(posedge clk);
        // wait (ready);
        // @(posedge clk);
        repeat (26) @(posedge clk);
        in_data  = 64'h33445566778899AA;
        in_valid = 1;
        is_last  = 1;
        byte_num = 3'd7;  // all 8 bytes used

        @(posedge clk);
        in_valid = 0;
        is_last  = 0;

        // // Wait for output
        wait (out_valid);
        $display("Output Ready: %h", out_data);

        out_ready = 1;
        @(posedge clk);
        out_ready = 0;

        // // Wait for DONE
        // wait (done);
        // $display("SHAKE Core DONE");

        #2000;
        $finish;
    end

    // ------------------------------------------------------------------------
    // Monitor (for debug)
    // ------------------------------------------------------------------------
    // always @(posedge clk) begin
    //     if (out_valid)
    //         $display("[%0t] OUT_VALID -> %h", $time, out_data[63:0]);
    // end
endmodule
