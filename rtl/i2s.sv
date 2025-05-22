module I2S #(
    parameter int DATA_OUT_SIZE = 16,
    parameter int I2S_DATA_SIZE = 24,
    parameter int REDUCE_FACTOR = 2,
    parameter int CLK_FREQ      = 100_000_000,  // Frequência do clock do sistema
    parameter int I2S_CLK_FREQ  = 1_500_000
) (
    input  logic clk,
    input  logic rst_n,

    output logic i2s_clk,
    output logic i2s_ws,
    input  logic i2s_sd,

    output logic [DATA_OUT_SIZE - 1:0] pcm_out,
    output logic pcm_ready
);

    logic        i2s_ready;
    logic [23:0] i2s_out;

    // Instanciação do módulo
    i2s_capture #(
        .DATA_SIZE    (I2S_DATA_SIZE),
        .CLK_FREQ     (CLK_FREQ),
        .I2S_CLK_FREQ (I2S_CLK_FREQ)
    ) u_i2s_receiver (
        .clk        (clk),
        .rst_n      (rst_n),
        
        .i2s_clk    (i2s_clk),
        .i2s_ws     (i2s_ws),
        .i2s_sd     (i2s_sd),
        
        .audio_data (i2s_out),
        .ready      (i2s_ready)  // A cada 24_414Hz
    );

        // Para estimar o tempo necessário até a memória FIFO encher completamente:
    //
    // 1. Determine o tamanho de cada amostra em bytes (nesse caso: 3 bytes por amostra).
    // 2. Calcule a taxa efetiva de amostragem 
    //                                         (nesse caso: 24.414 Hz / REDUCE_FACTOR ≈ 12 kHz).
    // 3. Multiplique o tamanho da amostra pela taxa de amostragem para obter a taxa de dados 
    //                                         (nesse caso: 2 bytes * 12KHz = 24 kB/s).
    // 4. Divida a capacidade total da FIFO (em bytes) pela taxa de dados para obter o tempo até encher:
    //                                          tempo ≈ capacidade_da_FIFO / taxa_de_dados
    //                                          nesse caso: 64 kB / 24 kB/s ≈ 2.66 segundos

    logic        done_reduce;
    logic [23:0] reduce_out;

    sample_reduce #(
        .DATA_SIZE      (I2S_DATA_SIZE),
        .REDUCE_FACTOR  (REDUCE_FACTOR)  // 24_414Hz / REDUCE_FACTOR gera a nova taxa de amostragem
    ) u_sample_reduce (
        .clk            (clk),
        .rst_n          (rst_n),

        .ready_i2s      (i2s_ready),
        .audio_data_in  (i2s_out),

        .done           (done_reduce),
        .audio_data_out (reduce_out)
    );
/*
    logic        fir_ready;
    logic [23:0] fir_out;

    fir_pipeline #(
        .DATA_WIDTH (24),
        .TAP_NUM    (64)
    ) fir_inst (
        .clk       (clk),
        .rst_n     (rst_n),

        .in_valid  (done_reduce),
        .in_data   (reduce_out),

        .out_valid (fir_ready),
        .out_data  (fir_out)
    );
*/
    assign pcm_ready = done_reduce;
    assign pcm_out   = reduce_out;
/*
    localparam DIFF = I2S_DATA_SIZE - DATA_OUT_SIZE;
    localparam ROUND_VALUE = 2 ^ (DIFF - 1);


    logic sum_ready;
    logic [I2S_DATA_SIZE - 1: 0] sum_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sum_ready <= 0;
            sum_data  <= 0;
            pcm_ready <= 0;
            pcm_out   <= 0;
        end else begin
            sum_ready <= done_reduce;
            sum_data  <= reduce_out + ROUND_VALUE;

            pcm_ready <= sum_ready;
            pcm_out   <= sum_data >>> DIFF;
        end
    end
*/
    
endmodule