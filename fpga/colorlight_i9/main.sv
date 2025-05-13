module main (
    input logic clk,  // board clock 25mhz 

    input  logic M_DATA,     // microfone data
    output logic M_CLK,  // microfone clock
    output logic M_LRSEL,    // Left/Right Select

    input  logic cs,    // enable spi
    input  logic mosi,
    input  logic sck,
    output logic miso,

    output logic [15:0] pcm_out,
    output logic        pcm_ready,
    input  logic        rst_n,

    output logic [7:0] LED
);

    logic fifo_empty;
    logic fifo_full;
    logic [13:0] full_count;
    i2s_fpga #(
        .CLK_FREQ      (25_000_000),  // Frequência do clock do sistema
        .FIFO_DEPTH    (32 * 1024), // 512kB
        .FIFO_WIDTH    (8),
        .DATA_SIZE     (24),
        .REDUCE_FACTOR (2)
    ) u_i2s_fpga (
        .clk        (clk),
        .rst_n      (rst_n),

        .mosi       (mosi),
        .miso       (miso),
        .cs         (cs),
        .sck        (sck),
 
        .i2s_clk    (M_CLK),
        .i2s_ws     (M_LRSEL),
        .i2s_sd     (M_DATA),
 
        .full_count (full_count),
        .fifo_empty (fifo_empty),
        .fifo_full  (fifo_full)
    );
    assign LED[1] = fifo_empty;
    assign LED[0] = fifo_full;
    assign LED[15:2] = full_count[13:0];
    
endmodule

