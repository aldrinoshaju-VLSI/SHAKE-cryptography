module absorb_unit #(
    parameter RATE_BITS = 1088
)(
    input              clk,
    input              reset,
    input              in_valid,
    input  [63:0]      in_data,
    output reg         ready,
    output reg         full,
    output reg [RATE_BITS-1:0] rate_buf
);

    localparam S_EMPTY   = 2'd0;
    localparam S_LOADING = 2'd1;
    localparam S_FULL    = 2'd2;

    reg [1:0] state;
    reg [$clog2(RATE_BITS/64):0] word_cnt;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= S_EMPTY;
            word_cnt  <= 0;
            rate_buf  <= 0;
            full      <= 0;
            ready     <= 1;
        end else begin
            case (state)
                S_EMPTY: begin
                    ready <= 1;
                    full  <= 0;
                    if (in_valid) begin
                        rate_buf[63:0] <= in_data;
                        word_cnt <= 1;
                        state <= S_LOADING;
                    end
                end

                S_LOADING: begin
                    ready <= 1;
                    if (in_valid) begin
                        rate_buf[word_cnt*64 +: 64] <= in_data;
                        word_cnt <= word_cnt + 1;
                        if (word_cnt == (RATE_BITS/64 - 1)) begin
                            state <= S_FULL;
                        end
                    end
                end

                S_FULL: begin
                    ready <= 0;
                    full  <= 1;
                    // Wait until main core acknowledges
                    // (e.g., when permutation done)
                    if (!in_valid) begin
                        state    <= S_EMPTY;
                        word_cnt <= 0;
                    end
                end
            endcase
        end
    end
endmodule
