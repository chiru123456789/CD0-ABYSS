`timescale 1ns/1ps

module tb_lfm_chirp_controller;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg start = 0;
    reg advance = 0;
    reg [31:0] start_word = 0;
    reg [31:0] step_word = 0;
    reg [15:0] sample_count = 0;

    wire [31:0] frequency_word;
    wire active;
    wire done;

    integer i;

    lfm_chirp_controller dut (
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

    initial begin
        $dumpfile("lfm_chirp_controller.vcd");
        $dumpvars(0, tb_lfm_chirp_controller);

        repeat (2) @(negedge clk);
        rst_n = 1;

        @(negedge clk);
        start_word = 32'd1000;
        step_word = 32'd100;
        sample_count = 16'd8;
        start = 1;

        @(posedge clk);
        #1;

        if (frequency_word !== 1000 || !active || done)
            $fatal(1, "FAIL: chirp start");

        @(negedge clk);
        start = 0;
        advance = 1;

        for (i = 1; i <= 8; i = i + 1) begin
            @(posedge clk);
            #1;

            if (i < 8) begin
                if (frequency_word !== (1000 + i * 100) ||
                    !active || done)
                    $fatal(1, "FAIL: chirp step %0d", i);
            end else begin
                if (frequency_word !== 1700 ||
                    active || !done)
                    $fatal(1, "FAIL: chirp completion");
            end
        end

        @(negedge clk);
        advance = 0;

        @(posedge clk);
        #1;

        if (done || active || frequency_word !== 1700)
            $fatal(1, "FAIL: completion hold");

        $display("PASS: LFM chirp start, 8 advances, completion and hold");
        $finish;
    end
endmodule
