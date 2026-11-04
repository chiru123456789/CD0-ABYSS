`timescale 1ns/1ps

module tb_dds_capture;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg enable = 0;
    reg load_config = 0;
    reg [31:0] frequency_word = 0;
    reg [31:0] phase_offset = 0;

    wire [11:0] sample;
    wire [7:0] phase_index;

    integer file_handle;
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
        repeat (2) @(negedge clk);
        rst_n = 1;

        // Configure the DDS before enabling accumulation.
        @(negedge clk);
        frequency_word = 32'h01000000;
        load_config = 1;

        @(posedge clk);
        #1;

        @(negedge clk);
        load_config = 0;
        enable = 1;

        file_handle = $fopen("plots/dds_capture.csv", "w");

        if (file_handle == 0) begin
            $display("FAIL: Cannot open capture file");
            $fatal(1);
        end

        $fdisplay(file_handle, "cycle,phase_index,sample");

        for (i = 1; i <= 1024; i = i + 1) begin
            @(posedge clk);
            #1;

            $fdisplay(file_handle, "%0d,%0d,%0d",
                      i, phase_index, sample);
        end

        $fclose(file_handle);

        $display("PASS: Captured 1024 RTL DDS samples");
        $finish;
    end
endmodule
