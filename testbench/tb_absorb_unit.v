`timescale 1ns/1ps

`include "../absorb_unit.v"
module tb_absorb_unit;

  // ---------------- Params you can tweak ----------------
  localparam integer RATE_BITS = 1088;       // 1344 for SHAKE128, 1088 for SHAKE256
  localparam integer WORDS     = RATE_BITS/64;

  // ---------------- DUT I/O ----------------
  reg                  clk;
  reg                  reset;
  reg                  in_valid;
  reg  [63:0]          in_data;
  wire                 ready;
  wire                 full;
  wire [RATE_BITS-1:0] rate_buf;

  // ---------------- Instantiate DUT ----------------
  absorb_unit #(
    .RATE_BITS(RATE_BITS)
  ) dut (
    .clk      (clk),
    .reset    (reset),
    .in_valid (in_valid),
    .in_data  (in_data),
    .ready    (ready),
    .full     (full),
    .rate_buf (rate_buf)
  );

  // ---------------- Clock ----------------
  initial clk = 1'b0;
  always  #5 clk = ~clk;   // 100 MHz

  // ---------------- VCD dump ----------------
  initial begin
    $dumpfile("../vcd_files/absorb_unit_wave.vcd");
    $dumpvars(0, tb_absorb_unit);
  end

  // ---------------- Test stimulus ----------------
  integer i;
  reg [63:0] vec   [0:WORDS-1];
  reg [RATE_BITS-1:0] expected;

  // Pack an expected RATE block given vec[0..WORDS-1]
  task build_expected;
    integer k;
    begin
      expected = {RATE_BITS{1'b0}};
      for (k = 0; k < WORDS; k = k + 1) begin
        // Same mapping the DUT uses:
        // first word into [63:0], next into [127:64], etc.
        expected[k*64 +: 64] = vec[k];
      end
    end
  endtask

  // Send one 64-bit beat (1 cycle), assumes 'ready' is asserted in LOADING
  task send_word(input [63:0] w);
    begin
      // Optional: wait for ready (defensive)
      wait (ready === 1'b1);
      @(posedge clk);
      in_data  <= w;
      in_valid <= 1'b1;
      @(posedge clk);
      in_valid <= 1'b0;
    end
  endtask

  // Sane reset
  task do_reset;
    begin
      reset   = 1'b1;
      in_valid= 1'b0;
      in_data = 64'd0;
      repeat (3) @(posedge clk);
      reset   = 1'b0;
      @(posedge clk);
    end
  endtask

  // ---------------- Main test ----------------
  initial begin
    $display("==== absorb_unit TB start (RATE_BITS=%0d, WORDS=%0d) ====", RATE_BITS, WORDS);
    do_reset();

    // Build a simple, distinctive pattern for each word
    for (i = 0; i < WORDS; i = i + 1) begin
      vec[i] = 64'hF0F0_0000_0000_0000 | i;  // low bits count up
    end
    build_expected();

    // Feed all words, one per cycle
    for (i = 0; i < WORDS; i = i + 1) begin
      send_word(vec[i]);
    end

    // FULL should assert after the last word (or next cycle)
    // Give it a couple of cycles to settle if your FSM flags on the next edge
    repeat (2) @(posedge clk);

    if (full !== 1'b1) begin
      $display("[%0t] ERROR: full did not assert after %0d words!", $time, WORDS);
      $fatal(1);
    end else begin
      $display("[%0t] INFO : full asserted (block ready).", $time);
    end

    // Compare the buffer
    if (rate_buf !== expected) begin
      $display("[%0t] ERROR: rate_buf mismatch!", $time);
      $display("Expected: %0h", expected);
      $display("Got     : %0h", rate_buf);
      $fatal(1);
    end else begin
      $display("[%0t] OK   : rate_buf matches expected.", $time);
    end

    // Deassert input (idle) to allow DUT to return to EMPTY if that’s your protocol
    @(posedge clk);
    in_valid <= 1'b0;
    in_data  <= 64'd0;

    // Let things run a few cycles for waveform
    repeat (10) @(posedge clk);

    $display("==== absorb_unit TB PASS ====");
    $finish;
  end

  // ---------------- Optional monitors ----------------
  always @(posedge clk) begin
    if (in_valid)
      $display("[%0t] beat sent: in_data=%h", $time, in_data);
    if (full)
      $display("[%0t] FULL=1 (block ready)", $time);
  end

endmodule
