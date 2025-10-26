// ============================================================================
// Dummy Keccak Permutation (for FSM Testing)
// ----------------------------------------------------------------------------
// • Simply copies state_in → state_out after a few cycles.
// • Useful for verifying FSM transitions and handshakes.
// ----------------------------------------------------------------------------
module keccak_permutation (
    input              clk,
    input              reset,
    input              start,         // trigger permutation
    input  [1599:0]    state_in,
    output reg [1599:0] state_out,
    output reg         done
);
    reg [4:0] counter;  // delay counter to simulate computation time

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter   <= 0;
            done      <= 0;
            state_out <= 1600'd0;
        end else begin
            if(start && counter == 0) begin
                counter <= 5'd24; // start counting down
                done    <= 0;
            end 
            if (counter > 0) begin
                counter <= counter - 1'b1;
                if (counter == 1) begin
                    state_out <= state_in; // just echo back
                    done      <= 1'b1;     // signal completion
                end else begin
                    done <= 0;
                end
            end else begin
                done <= 0;
            end
        end
    end
endmodule
