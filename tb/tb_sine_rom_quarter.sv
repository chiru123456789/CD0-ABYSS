`timescale 1ns/1ps

module tb_sine_rom_quarter;

    reg [7:0] address = 0;

    wire [11:0] original_sample;
    wire [11:0] quarter_sample;

    integer i;
    integer errors = 0;

    dds_sine_rom original (
        .address(address),
        .sample(original_sample)
    );

    dds_sine_rom_quarter optimized (
        .address(address),
        .sample(quarter_sample)
    );

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            address = i;
            #1;

            if (original_sample !== quarter_sample) begin
                $display(
                    "MISMATCH address=%0d original=%0d quarter=%0d",
                    i, original_sample, quarter_sample
                );
                errors = errors + 1;
            end
        end

        if (errors != 0)
            $fatal(1, "FAIL: %0d mismatches", errors);

        $display("PASS: All 256 ROM samples match exactly");
        $finish;
    end

endmodule
