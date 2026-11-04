`timescale 1ns/1ps

module tb_lfm_wavecore;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg start = 0;
    reg advance = 0;
    reg [31:0] start_word = 0;
    reg [31:0] step_word = 0;
    reg [15:0] sample_count = 0;

    wire [11:0] sample;
    wire [7:0] phase_index;
    wire [31:0] frequency_word;
    wire active;
    wire done;

    reg [31:0] expected_phase = 0;
    reg [31:0] expected_word;
    reg [11:0] reference_rom [0:255];
    integer i;

    lfm_wavecore dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .advance(advance),
        .start_word(start_word),
        .step_word(step_word),
        .sample_count(sample_count),
        .sample(sample),
        .phase_index(phase_index),
        .frequency_word(frequency_word),
        .active(active),
        .done(done)
    );

    initial begin
        $readmemh("rtl/rom/sine_256x12.hex", reference_rom);
        $dumpfile("lfm_wavecore.vcd");
        $dumpvars(0, tb_lfm_wavecore);

        repeat (2) @(negedge clk);
        rst_n = 1;

        @(negedge clk);
        start_word = 32'h01000000;
        step_word = 32'h00100000;
        sample_count = 16'd64;
        start = 1;

        @(posedge clk);
        #1;

        if (!active || frequency_word !== start_word ||
            phase_index !== 0)
            $fatal(1, "FAIL: initial chirp configuration");

        @(negedge clk);
        start = 0;
        advance = 1;

        for (i = 0; i < 64; i = i + 1) begin
            expected_word = start_word + i * step_word;

            @(posedge clk);
            #1;

            expected_phase = expected_phase + expected_word;

            if (phase_index !== expected_phase[31:24])
                $fatal(1, "FAIL: phase at step %0d", i);

            if (sample !== reference_rom[expected_phase[31:24]])
                $fatal(1, "FAIL: sample at step %0d", i);
        end

        if (!done || active)
            $fatal(1, "FAIL: completion state");

        $display("PASS: 64-sample integrated LFM chirp");
        $finish;
    end
endmodule
