//`define COMPRESS_OUT 1
//`define SPI_RST_EN 1

module top (
    input logic clk, // 50MHz

    output logic [7:0] LED,

    input  logic mosi,
    output logic miso,
    input  logic sck,
    input  logic cs,

    input  logic rst,
    input  logic soft_reset, 

    output logic i2s_clk,  // Clock do I2S
    output logic i2s_ws,   // Word Select do I2S
    input  logic i2s_sd    // Dados do I2S
);

    logic rst_n = !rst;
    logic sys_rst_n;

`ifdef SPI_RST_EN
    assign sys_rst_n = rst_n & !spi_rst;
`else
    assign sys_rst_n = rst_n;
`endif

    i2s_fpga #(
        .CLK_FREQ        (50_000_000),  // Frequência do clock do sistema
        .I2S_CLK_FREQ    (1_500_000),
        .FIFO_DEPTH      (64 * 1024), // 64kB
        .FIFO_WIDTH      (8),
        .DATA_SIZE       (24),
        .REDUCE_FACTOR   (2),
        .SIZE_FULL_COUNT (14)
    ) u_i2s_fpga (
        .clk        (clk),
        .rst_n      (sys_rst_n),
        
        .mosi       (mosi),
        .miso       (miso),
        .cs         (cs),
        .sck        (sck),

        .i2s_clk    (i2s_clk),
        .i2s_ws     (i2s_ws),
        .i2s_sd     (i2s_sd),

        .full_count (LED[7:2]),
        .fifo_empty (LED[1]),
        .fifo_full  (LED[0])
    );

endmodule
