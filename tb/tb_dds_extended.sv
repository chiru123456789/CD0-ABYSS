`timescale 1ns/1ps

module tb_dds_extended;
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
    reg [31:0] expected_phase = 0;
    reg [31:0] active_word = 0;
    reg [31:0] next_phase;
    reg [31:0] next_word;
    reg [31:0] expected_index;

    integer i;
    integer checks = 0;

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
        $dumpfile("dds_extended.vcd");
        $dumpvars(0, tb_dds_extended);

        repeat (2) @(negedge clk);
        rst_n = 1;

        for (i = 0; i < 2000; i = i + 1) begin
            // Configure inputs before the next rising edge.
            enable = (i % 13 != 0);
            load_config = (
                i == 0 || i == 250 || i == 500 ||
                i == 1000 || i == 1500
            );

            case (i)
                0:    frequency_word = 32'h01000000;
                250:  frequency_word = 32'h02468ACE;
                500:  frequency_word = 32'h10000000;
                1000: frequency_word = 32'h80000000;
                1500: frequency_word = 32'hFFFFFFFF;
            endcase

            phase_offset = (i >= 750 && i < 1250)
                         ? 32'h40000000 : 32'h00000000;

            // Nonblocking assignments use the previous active word.
            next_word = load_config ? frequency_word : active_word;
            next_phase = enable
                       ? expected_phase + active_word
                       : expected_phase;

            @(posedge clk);
            #1;

            active_word = next_word;
            expected_phase = next_phase;

            expected_index =
                (expected_phase + phase_offset) >> 24;

            if (phase_index !== expected_index[7:0]) begin
                $display(
                    "FAIL phase cycle=%0d expected=%0d actual=%0d",
                    i, expected_index[7:0], phase_index
                );
                $fatal(1);
            end

            if (sample !== reference_rom[expected_index[7:0]]) begin
                $display(
                    "FAIL sample cycle=%0d expected=%0d actual=%0d",
                    i, reference_rom[expected_index[7:0]], sample
                );
                $fatal(1);
            end

            checks = checks + 1;
            @(negedge clk);
        end

        $display(
            "PASS: %0d cycles across five frequency configurations, phase offsets and enable holds",
            checks
        );
        $finish;
    end
endmodule
