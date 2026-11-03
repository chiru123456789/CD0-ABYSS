// ClockDomain Zero — DDS phase generator, synthesizable Verilog subset.
// The top PHASE_BITS bits form the ROM index for a downstream sine LUT.
// IMPORTANT: phase output only; this file does NOT generate analogue samples.
module dds_phase_core #(
    parameter integer PHASE_BITS = 8
) (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire load_config,
    input wire [31:0] frequency_word,
    input wire [31:0] phase_offset,
    output wire [PHASE_BITS-1:0] phase_index,
    output reg [31:0] phase_accumulator
);
    reg [31:0] active_frequency_word;
    assign phase_index = (phase_accumulator + phase_offset) >> (32 - PHASE_BITS);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_accumulator <= 32'd0;
            active_frequency_word <= 32'd0;
        end else begin
            if (load_config)
                active_frequency_word <= frequency_word;
            if (enable)
                phase_accumulator <= phase_accumulator + active_frequency_word;
        end
    end
endmodule
