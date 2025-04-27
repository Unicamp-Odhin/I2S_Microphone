module top (
    input logic clk,
    input logic CPU_RESETN,

    input  logic rx,
    output logic tx,

    input  logic [15:0] SW,
    output logic [15:0] LED,

    input  logic mosi,
    output logic miso,
    input  logic sck,
    input  logic cs,

    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B,
    output logic       VGA_HS,
    output logic       VGA_VS,

    output logic M_CLK,   // Clock do microfone
    output logic M_LRSEL, // Left/Right Select (Escolha do canal)

    input logic M_DATA,  // Dados do microfone

    output logic i2s_clk,  // Clock do I2S
    output logic i2s_ws,   // Word Select do I2S
    input  logic i2s_sd,   // Dados do I2S

    output logic [7:0] JC
);

    logic fifo_empty;
    logic fifo_full;
    i2s_fpga #(
        .CLK_FREQ(50_000_000),  // Frequência do clock do sistema
        .FIFO_DEPTH(512 * 1024), // 512kB
        .FIFO_WIDTH(8),
        .DATA_SIZE(24),
        .REDUCE_FACTOR(2),
    ) u_i2s_fpga (
        .clk       (clk),
        .rst       (CPU_RESETN),
        .mosi      (mosi),
        .miso      (miso),
        .cs        (cs),
        .sck       (sck),

        .i2s_clk   (i2s_clk),
        .i2s_ws    (i2s_ws),
        .i2s_sd    (i2s_sd)

        .full_count(LED[15:2]),
        .fifo_empty(fifo_empty),
        .fifo_full (fifo_full)
    );

    assign LED[1] = fifo_empty;
    assign LED[0] = fifo_full;

    assign VGA_R        = 4'b0000;
    assign VGA_G        = 4'b0000;
    assign VGA_B        = 4'b0000;
    assign VGA_HS       = 1'b0;
    assign VGA_VS       = 1'b0;

    assign JC[0]        = ~fifo_empty;
    assign JC[1]        = 1'b1;
    assign JC[2]        = ~fifo_full;
    assign JC[3]        = 1'b1;
    assign JC[4]        = 1'b1;
    assign JC[5]        = 1'b1;
    assign JC[6]        = 1'b1;
    assign JC[7]        = 1'b1;

endmodule

