`timescale 1ns/1ps

module tb_lfm_edge_cases;
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

    integer checks = 0;

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

    task tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task check;
        input [31:0] word;
        input expected_active;
        input expected_done;
        begin
            if (frequency_word !== word ||
                active !== expected_active ||
                done !== expected_done) begin
                $display(
                    "FAIL check=%0d word=%0d active=%b done=%b",
                    checks, frequency_word, active, done
                );
                $fatal(1);
            end
            checks = checks + 1;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;

        // Test 1: Zero-length chirp
        start = 1;
        start_word = 32'd100;
        step_word = 32'd10;
        sample_count = 0;
        tick();
        check(100, 0, 0);

        // Test 2: Start and pause
        @(negedge clk);
        start = 1;
        sample_count = 4;
        tick();
        check(100, 1, 0);

        @(negedge clk);
        start = 0;
        advance = 0;
        repeat (3) begin
            tick();
            check(100, 1, 0);
            @(negedge clk);
        end

        // Test 3: Resume
        advance = 1;
        tick();
        check(110, 1, 0);

        @(negedge clk);
        tick();
        check(120, 1, 0);

        // Test 4: Restart during active chirp
        @(negedge clk);
        start = 1;
        start_word = 32'd500;
        step_word = 32'd25;
        sample_count = 2;
        tick();
        check(500, 1, 0);

        @(negedge clk);
        start = 0;
        tick();
        check(525, 1, 0);

        @(negedge clk);
        tick();
        check(525, 0, 1);

        // Test 5: Frequency-word wraparound
        @(negedge clk);
        start = 1;
        start_word = 32'hFFFFFFF0;
        step_word = 32'h00000020;
        sample_count = 2;
        tick();
        check(32'hFFFFFFF0, 1, 0);

        @(negedge clk);
        start = 0;
        tick();
        check(32'h00000010, 1, 0);

        // Test 6: Reset during operation
        @(negedge clk);
        rst_n = 0;
        #1;
        check(0, 0, 0);

        $display(
            "PASS: %0d LFM edge-case checks",
            checks
        );
        $finish;
    end
endmodule
