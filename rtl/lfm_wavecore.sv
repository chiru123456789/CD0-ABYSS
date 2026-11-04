module lfm_wavecore (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        advance,
    input  wire [31:0] start_word,
    input  wire [31:0] step_word,
    input  wire [15:0] sample_count,
    output wire [11:0] sample,
    output wire [7:0]  phase_index,
    output wire [31:0] frequency_word,
    output wire        active,
    output wire        done
);
    reg [31:0] phase_accumulator;

    lfm_chirp_controller chirp (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .advance(advance),
        .start_word(start_word),
        .step_word(step_word),
        .sample_count(sample_count),
        .frequency_word(frequency_word),
        .active(active),
        .done(done)
    );

    assign phase_index = phase_accumulator[31:24];

    dds_sine_rom sine_rom (
        .address(phase_index),
        .sample(sample)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            phase_accumulator <= 32'd0;
        else if (start)
            phase_accumulator <= 32'd0;
        else if (active && advance)
            phase_accumulator <= phase_accumulator + frequency_word;
    end
endmodule
