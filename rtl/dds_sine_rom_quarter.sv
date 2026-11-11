module dds_sine_rom_quarter (
    input  wire [7:0]  address,
    output wire [11:0] sample
);

    reg [11:0] quarter_rom [0:64];

    initial begin
        $readmemh(
            "rtl/rom/sine_quarter_65x12.hex",
            quarter_rom
        );
    end

    wire [1:0] quadrant = address[7:6];
    wire [5:0] offset = address[5:0];

    wire [6:0] quarter_index =
        quadrant[0] ? (7'd64 - {1'b0, offset})
                    : {1'b0, offset};

    wire [11:0] positive_sample =
        quarter_rom[quarter_index];

    // Exact offset-binary symmetry for this ROM's
    // 0..4095 quantization convention.
    assign sample = (address == 8'd128)
        ? 12'd2048
        : quadrant[1]
            ? (12'd4095 - positive_sample)
            : positive_sample;

endmodule
