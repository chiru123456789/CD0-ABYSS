module dds_wavecore (
    input  wire clk,
    input  wire rst_n,
    input  wire enable,
    input  wire load_config,
    input  wire [31:0] frequency_word,
    input  wire [31:0] phase_offset,
    output wire [11:0] sample,
    output wire [7:0] phase_index
);
    wire [31:0] phase_accumulator;

    dds_phase_core #(
        .PHASE_BITS(8)
    ) phase_core (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .load_config(load_config),
        .frequency_word(frequency_word),
        .phase_offset(phase_offset),
        .phase_index(phase_index),
        .phase_accumulator(phase_accumulator)
    );

    dds_sine_rom sine_rom (
        .address(phase_index),
        .sample(sample)
    );
endmodule
