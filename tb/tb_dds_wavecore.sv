
`timescale 1ns/1ps

module tb_dds_wavecore;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg enable = 0;
    reg load_config = 0;
    reg [31:0] frequency_word = 0;
    reg [31:0] phase_offset = 0;

    wire [11:0] sample;
    wire [7:0] phase_index;

    reg [11:0] reference_rom [0:255];
    integer i;

    dds_wavecore dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .load_config(load_config),
        .frequency_word(frequency_word),
        .phase_offset(phase_offset),
        .sample(sample),
        .phase_index(phase_index)
    );

    initial begin
        $readmemh("rtl/rom/sine_256x12.hex", reference_rom);

        $dumpfile("dds_wavecore.vcd");
        $dumpvars(0, tb_dds_wavecore);

        // Release reset on a falling clock edge.
        repeat (2) @(negedge clk);
        rst_n = 1;

        // Test all 256 sine ROM addresses.
        // DDS is disabled, so the phase accumulator stays at zero.
        for (i = 0; i < 256; i = i + 1) begin
            phase_offset = i * 32'h01000000;
            #1;

            if (phase_index !== i[7:0] ||
                sample !== reference_rom[i]) begin
                $display(
                    "FAIL ROM index=%0d expected=%0d got=%0d",
                    i, reference_rom[i], sample
                );
                $fatal(1);
            end
        end

        // Configure DDS frequency: one ROM address per clock.
        // Apply configuration at a falling edge.
        @(negedge clk);
        phase_offset = 0;
        frequency_word = 32'h01000000;
        load_config = 1;
        enable = 0;

        // Wait for the rising edge that captures frequency_word.
        @(posedge clk);
        #1;

        // Start DDS at the next falling edge.
        @(negedge clk);
        load_config = 0;
        enable = 1;

        // Verify 256 successive DDS samples, including wraparound.
        for (i = 1; i <= 256; i = i + 1) begin
            @(posedge clk);
            #1;

            if (phase_index !== (i % 256) ||
                sample !== reference_rom[i % 256]) begin
                $display(
                    "FAIL DDS cycle=%0d expected_index=%0d got_index=%0d expected_sample=%0d got_sample=%0d",
                    i, i % 256, phase_index,
                    reference_rom[i % 256], sample
                );
                $fatal(1);
            end
        end

        $display("PASS: 256 ROM addresses and 256 DDS cycles");
        $finish;
    end
endmodule
