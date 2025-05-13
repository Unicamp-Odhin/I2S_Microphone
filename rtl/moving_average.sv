module Moving_Averange #(
    parameter DATA_WIDTH = 16,
    parameter FIR_TAPS   = 64
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         in_valid,
    input  logic signed [DATA_WIDTH-1:0] in_sample,
    output logic                         out_valid,
    output logic signed [DATA_WIDTH-1:0] out_sample
);
    integer k;

    logic        [DATA_WIDTH - 1    :0] fir_buffer [0:FIR_TAPS-1];
    logic signed [DATA_WIDTH * 2 - 1:0] fir_sum;
    logic        [5:0]                  fir_index;

    logic fir_ready;
    logic signed [31:0] fir_avg;

    // FIR Filter Stage
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fir_sum   <= 0;
            fir_index <= 0;
            fir_avg   <= 0;
            fir_ready <= 0;

            for (k = 0; k < FIR_TAPS; k = k + 1) fir_buffer[k] <= 0;
        end else if (in_valid) begin
            // Atualiza o buffer com o novo valor de entrada
            fir_buffer[fir_index] <= in_sample;
            fir_index <= (fir_index + 1) % FIR_TAPS;

            // Calcula a soma de todos os taps do filtro FIR
            fir_sum = 0;
            for (k = 0; k < FIR_TAPS; k = k + 1) begin
                fir_sum = fir_sum + fir_buffer[k];
            end

            // Normaliza a saída e envia para pcm_out
            fir_avg  <= fir_sum >> $clog2(FIR_TAPS);
            fir_ready <= 1;
        end else begin
            fir_ready <= 0;
        end
    end

    always_ff @( posedge clk ) begin
        if (!rst_n) begin
            out_sample <= 0;
            out_valid  <= 0;
        end else if(fir_ready) begin
            out_sample <= $signed(fir_avg[15:0]);
            out_valid  <= 1;
        end else begin
            out_valid  <= 0;
        end
    end
    
endmodule
