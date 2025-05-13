module top (
    input logic clk,
    input logic rst_n,

    output logic [7:0] led,

    input  logic mosi,
    output logic miso,
    input  logic sck,
    input  logic cs,

    output logic i2s_clk,  // Clock do I2S
    output logic i2s_ws,   // Word Select do I2S
    input  logic i2s_sd    // Dados do I2S
);

    i2s_fpga #(
        .CLK_FREQ        (50_000_000),  // Frequência do clock do sistema
        .I2S_CLK_FREQ    (1_500_000),
        .FIFO_DEPTH      (1536 * 1024), // 64kB
        .FIFO_WIDTH      (8),
        .DATA_SIZE       (24),
        .REDUCE_FACTOR   (2),
        .SIZE_FULL_COUNT (14)
    ) u_i2s_fpga (
        .clk        (clk),
        .rst_n      (rst_n),
        .mosi       (mosi),
        .miso       (miso),
        .cs         (cs),
        .sck        (sck),
 
        .i2s_clk    (i2s_clk),
        .i2s_ws     (i2s_ws),
        .i2s_sd     (i2s_sd),
 
        .full_count (led[7:2]),
        .fifo_empty (led[1]),
        .fifo_full  (led[0])
    );
endmodule
