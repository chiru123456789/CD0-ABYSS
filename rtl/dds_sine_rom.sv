module dds_sine_rom (
    input  wire [7:0] address,
    output wire [11:0] sample
);
    reg [11:0] rom [0:255];

    initial begin
        $readmemh("rtl/rom/sine_256x12.hex", rom);
    end

    assign sample = rom[address];
endmodule
