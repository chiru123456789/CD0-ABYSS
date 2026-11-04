module lfm_chirp_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        advance,
    input  wire [31:0] start_word,
    input  wire [31:0] step_word,
    input  wire [15:0] sample_count,
    output reg  [31:0] frequency_word,
    output reg         active,
    output reg         done
);
    reg [15:0] samples_remaining;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frequency_word <= 32'd0;
            samples_remaining <= 16'd0;
            active <= 1'b0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start) begin
                frequency_word <= start_word;
                samples_remaining <= sample_count;
                active <= (sample_count != 0);
            end else if (active && advance) begin
                if (samples_remaining == 16'd1) begin
                    samples_remaining <= 16'd0;
                    active <= 1'b0;
                    done <= 1'b1;
                end else begin
                    samples_remaining <= samples_remaining - 16'd1;
                    frequency_word <= frequency_word + step_word;
                end
            end
        end
    end
endmodule
