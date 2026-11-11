`timescale 1ns/1ps

module tb_lfm_capture;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg start = 0;
    reg advance = 0;

    reg [31:0] start_word = 32'h01000000;
    reg [31:0] step_word = 32'h00100000;
    reg [15:0] sample_count = 16'd64;

    wire [11:0] sample;
    wire [7:0] phase_index;
    wire [31:0] frequency_word;
    wire active;
    wire done;

    integer file_handle;
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
        repeat (2) @(negedge clk);
        rst_n = 1;

        @(negedge clk);
        start = 1;

        @(posedge clk);
        #1;

        if (!active || frequency_word !== start_word)
            $fatal(1, "FAIL: chirp initialization");

        @(negedge clk);
        start = 0;
        advance = 1;

        file_handle = $fopen("plots/lfm_capture.csv", "w");

        if (file_handle == 0)
            $fatal(1, "FAIL: cannot create CSV");

        $fdisplay(
            file_handle,
            "cycle,phase_index,sample,frequency_word,active,done"
        );

        for (i = 0; i < 64; i = i + 1) begin
            @(posedge clk);
            #1;

            $fdisplay(
                file_handle,
                "%0d,%0d,%0d,%0d,%0d,%0d",
                i,
                phase_index,
                sample,
                frequency_word,
                active,
                done
            );
        end

        $fclose(file_handle);

        if (!done || active)
            $fatal(1, "FAIL: chirp completion");

        $display("PASS: Captured 64 LFM samples");
        $finish;
    end
endmodule
