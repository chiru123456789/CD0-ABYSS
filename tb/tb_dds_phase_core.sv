`timescale 1ns/1ps
module tb_dds_phase_core;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg enable = 0;
    reg load_config = 0;
    reg [31:0] frequency_word = 0;
    reg [31:0] phase_offset = 0;
    wire [7:0] phase_index;
    wire [31:0] phase_accumulator;
    reg [31:0] expected_phase = 0;
    reg [31:0] expected_word = 0;
    reg [31:0] next_phase;
    reg [31:0] next_word;
    integer i;
    dds_phase_core #(.PHASE_BITS(8)) dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .load_config(load_config), .frequency_word(frequency_word),
        .phase_offset(phase_offset), .phase_index(phase_index),
        .phase_accumulator(phase_accumulator)
    );
    initial begin
        $dumpfile("dds_phase_core.vcd");
        $dumpvars(0, tb_dds_phase_core);
        repeat (2) @(negedge clk);
        rst_n = 1;
        for (i=0; i<1000; i=i+1) begin
            // Drive exclusively at falling edges; sample AFTER rising-edge updates.
            enable = (i % 9 != 0);
            load_config = (i == 0 || i == 300 || i == 600);
            if (i == 0) frequency_word = 32'h01000000;
            if (i == 300) frequency_word = 32'h02468ACE;
            if (i == 600) frequency_word = 32'hFFFFFFFF;
            phase_offset = (i >= 500) ? 32'h40000000 : 32'h0;
            next_word = load_config ? frequency_word : expected_word;
            next_phase = enable ? expected_phase + expected_word : expected_phase;
            @(posedge clk); #1;
            expected_word = next_word;
            expected_phase = next_phase;
            if (phase_accumulator !== expected_phase ||
                phase_index !== ((expected_phase + phase_offset) >> 24)) begin
                $display("FAIL i=%0d expected=%h got=%h index=%h", i,
                         expected_phase, phase_accumulator, phase_index);
                $fatal(1);
            end
            @(negedge clk);
        end
        $display("PASS: 1000 cycles, config changes, hold, wraparound and phase offset");
        $finish;
    end
endmodule
