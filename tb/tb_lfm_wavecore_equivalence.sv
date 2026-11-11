`timescale 1ns/1ps

module tb_lfm_wavecore_equivalence;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg start = 0;
    reg advance = 0;
    reg [31:0] start_word = 0;
    reg [31:0] step_word = 0;
    reg [15:0] sample_count = 0;

    wire [11:0] sample_ref, sample_opt;
    wire [7:0] phase_ref, phase_opt;
    wire [31:0] freq_ref, freq_opt;
    wire active_ref, active_opt;
    wire done_ref, done_opt;

    integer checks = 0;
    integer i;

    lfm_wavecore reference_dut (
        .clk(clk), .rst_n(rst_n),
        .start(start), .advance(advance),
        .start_word(start_word),
        .step_word(step_word),
        .sample_count(sample_count),
        .sample(sample_ref),
        .phase_index(phase_ref),
        .frequency_word(freq_ref),
        .active(active_ref),
        .done(done_ref)
    );

    lfm_wavecore_quarter optimized_dut (
        .clk(clk), .rst_n(rst_n),
        .start(start), .advance(advance),
        .start_word(start_word),
        .step_word(step_word),
        .sample_count(sample_count),
        .sample(sample_opt),
        .phase_index(phase_opt),
        .frequency_word(freq_opt),
        .active(active_opt),
        .done(done_opt)
    );

    task compare_outputs;
        begin
            #1;

            if ({sample_ref, phase_ref, freq_ref,
                 active_ref, done_ref} !==
                {sample_opt, phase_opt, freq_opt,
                 active_opt, done_opt}) begin

                $display("FAIL at check %0d", checks);
                $display(
                    "REF: sample=%0d phase=%0d freq=%h active=%b done=%b",
                    sample_ref, phase_ref, freq_ref,
                    active_ref, done_ref
                );
                $display(
                    "OPT: sample=%0d phase=%0d freq=%h active=%b done=%b",
                    sample_opt, phase_opt, freq_opt,
                    active_opt, done_opt
                );

                $fatal(1, "Wavecore equivalence failed");
            end

            checks = checks + 1;
        end
    endtask

    task step_cycle;
        begin
            @(posedge clk);
            compare_outputs();
            @(negedge clk);
        end
    endtask

    initial begin
        // Initial reset
        rst_n = 0;
        repeat (3) step_cycle();
        rst_n = 1;

        // Normal chirp
        start_word = 32'h01000000;
        step_word = 32'h00100000;
        sample_count = 64;

        start = 1;
        step_cycle();
        start = 0;
        advance = 1;

        repeat (70) step_cycle();

        // Pause and resume
        start_word = 32'h04000000;
        step_word = 32'h00080000;
        sample_count = 100;
        start = 1;
        advance = 0;
        step_cycle();
        start = 0;

        repeat (30) step_cycle();

        advance = 1;
        repeat (40) step_cycle();

        advance = 0;
        repeat (15) step_cycle();

        advance = 1;
        repeat (80) step_cycle();

        // Restart during active chirp
        start_word = 32'h08000000;
        step_word = 32'h00010000;
        sample_count = 200;
        start = 1;
        advance = 0;
        step_cycle();
        start = 0;
        advance = 1;

        repeat (25) step_cycle();

        start_word = 32'h10000000;
        step_word = 32'h00020000;
        sample_count = 50;
        start = 1;
        step_cycle();
        start = 0;

        repeat (60) step_cycle();

        // Frequency-word wraparound
        start_word = 32'hFFFFFF00;
        step_word = 32'h00001000;
        sample_count = 100;
        advance = 0;
        start = 1;
        step_cycle();
        start = 0;
        advance = 1;

        repeat (110) step_cycle();

        // Zero-length chirp
        start_word = 32'h01000000;
        step_word = 32'h00010000;
        sample_count = 0;
        advance = 0;
        start = 1;
        step_cycle();
        start = 0;
        repeat (5) step_cycle();

        // Mid-operation reset
        sample_count = 100;
        start = 1;
        step_cycle();
        start = 0;
        advance = 1;
        repeat (20) step_cycle();

        rst_n = 0;
        repeat (3) step_cycle();
        rst_n = 1;

        // Deterministic randomized stimulus
        for (i = 0; i < 2000; i = i + 1) begin
            start = ($urandom_range(0, 99) < 3);
            advance = ($urandom_range(0, 99) < 75);

            if (start) begin
                start_word = $urandom;
                step_word = $urandom;
                sample_count = $urandom_range(0, 200);
            end

            step_cycle();
        end

        $display(
            "PASS: %0d wavecore equivalence checks",
            checks
        );

        $finish;
    end

endmodule
