// ============================================================================
// SHAKE-128/256 FSM Core (Simplified Skeleton)
// ----------------------------------------------------------------------------
// • Pure Verilog (no SystemVerilog enums)
// • Controls absorption, padding, permutation, and squeezing
// • Keccak-f[1600] permutation assumed as submodule `keccak_permutation`
// ----------------------------------------------------------------------------
// PARAMETERS
// RATE_BITS = 1344 for SHAKE128, 1088 for SHAKE256
// SUFFIX    = 8'h1F for SHAKE (domain separation)
// ============================================================================
`include "keccak_permutation.v"
module shake_core #(
    parameter integer RATE_BITS = 1344,
    parameter [7:0]   SUFFIX    = 8'h1F,
    parameter integer OUT_BITS  = 512
)(
    input               clk,
    input               reset,
    input               start,           // start absorption
    input               in_valid,        // input block valid
    input  [63:0]       in_data,         // 64-bit message input
    input               is_last,         // last block indicator
    input  [2:0]        byte_num,        // unused byte count for last block
    output reg          ready,           // ready to accept new input

    output reg          out_valid,       // output block valid
    output reg [OUT_BITS-1:0] out_data,  // output data
    input               out_ready,       // user accepted output

    output reg          done             // all complete
);

    // ------------------------------------------------------------------------
    // FSM State Encoding
    // ------------------------------------------------------------------------
    localparam [2:0]
        S_IDLE     = 3'd0,
        S_ABSORB   = 3'd1,
        S_PAD      = 3'd2,
        S_PERMUTE  = 3'd3,
        S_SQUEEZE  = 3'd4,
        S_DONE     = 3'd5;

    reg [2:0] state, next_state;

    // ------------------------------------------------------------------------
    // Internal Registers
    // ------------------------------------------------------------------------
    reg [1599:0] keccak_state;   // 1600-bit state
    reg [RATE_BITS-1:0] msg_buf; // rate portion buffer
    reg perm_start, perm_done;
    reg [4:0] round_cnt;         // 0–23 rounds
    reg [7:0] squeeze_cnt;       // block counter

    wire [1599:0] perm_state_out;
    wire          perm_done_w;

    reg was_permute;

    reg [2:0] state_d1;
    always @(posedge clk or posedge reset) begin
    if (reset) state_d1 <= S_IDLE;
    else       state_d1 <= state;
    end

    wire enter_permute = (state == S_PERMUTE) && (state_d1 != S_PERMUTE);

    always @(posedge clk or posedge reset) begin
        if (reset) perm_start <= 1'b0;
        else       perm_start <= enter_permute;  // exactly one clock
    end

    // ------------------------------------------------------------------------
    // Dummy Permutation (replace with real Keccak)
    // ------------------------------------------------------------------------
    keccak_permutation perm_core (
        .clk(clk),
        .reset(reset),
        .start(perm_start),
        .state_in(keccak_state),
        .state_out(perm_state_out),
        .done(perm_done_w)
    );

    // ------------------------------------------------------------------------
    // FSM Sequential Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // ------------------------------------------------------------------------
    // FSM Next-State Logic
    // ------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:     if (start) next_state = S_ABSORB;
            S_ABSORB:   if (is_last) next_state = S_PAD;
                        else if (in_valid) next_state = S_PERMUTE;
            S_PAD:      next_state = S_PERMUTE;
            S_PERMUTE:  if (perm_done_w) begin
                            if (in_valid && is_last)
                                next_state = S_PAD;
                            else if (in_valid)
                                next_state = S_ABSORB; 
                            else
                                next_state = S_SQUEEZE;
                        end
            S_SQUEEZE:  if (out_ready) next_state = S_DONE;
            S_DONE:     if (~start) next_state = S_IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // FSM Output and Datapath Control
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ready       <= 1'b1;
            out_valid   <= 1'b0;
            done        <= 1'b0;
            perm_start  <= 1'b0;
            round_cnt   <= 5'd0;
            squeeze_cnt <= 8'd0;
            msg_buf     <= {RATE_BITS{1'b0}};
            keccak_state<= 1600'd0;
        end else begin
            // assert start for one cycle when entering PERMUTE
            // if (state == S_PERMUTE && !perm_start)
            //     perm_start <= 1'b1;
            // else
            //     perm_start <= 1'b0;

            // when permutation finishes, latch the new state
            if (perm_done_w) begin
                // perm_done <= perm_done_w;
                keccak_state <= perm_state_out;
            end

            if(state != S_PERMUTE)
                perm_done <= 1'b0; // clear perm_done on state change

            case (state)

                // -------------------- IDLE --------------------
                S_IDLE: begin
                    ready     <= 1'b1;
                    done      <= 1'b0;
                    out_valid <= 1'b0;
                    squeeze_cnt <= 0;
                end

                // -------------------- ABSORB --------------------
                S_ABSORB: begin
                    ready <= 1'b0;
                    if (in_valid) begin
                        // absorb message into state (XOR into rate)
                        keccak_state[1599:1600-RATE_BITS] <= 
                            keccak_state[1599:1600-RATE_BITS] ^ in_data;
                        // was_permute <= 1'b0;
                    end
                end

                // -------------------- PAD --------------------
                S_PAD: begin
                    // apply SHAKE domain separation and pad10*1
                    keccak_state[1599:1600-RATE_BITS] <= 
                        keccak_state[1599:1600-RATE_BITS] ^ {SUFFIX, {(RATE_BITS-8){1'b0}}};
                    keccak_state[1599] <= keccak_state[1599] ^ 1'b1; // final pad '1'
                    // was_permute <= 1'b0;
                end

                // -------------------- PERMUTE --------------------
                S_PERMUTE: begin

                    // if(was_permute==1'b0)
                    //     perm_start <= 1'b1;
                    // else
                    //     was_permute <= 1'b1;

                    if (perm_done_w) begin
                        // perm_done <= 1'b0;
                        perm_start <= 1'b0;
                        ready <= 1'b1;
                    end
                end

                // -------------------- SQUEEZE --------------------
                S_SQUEEZE: begin
                    if (perm_done_w) begin
                        out_data  <= keccak_state[1599:1600-OUT_BITS];
                        out_valid <= 1'b1;
                    end
                    if (out_ready && out_valid) begin
                        squeeze_cnt <= squeeze_cnt + 1;
                        out_valid <= 1'b0;
                    end
                end

                // -------------------- DONE --------------------
                S_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule
