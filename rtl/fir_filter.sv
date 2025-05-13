module fir_pipeline #(
    parameter DATA_WIDTH = 16,
    parameter TAP_NUM    = 64
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          in_valid,
    input  logic signed [DATA_WIDTH-1:0]  in_data,
    output logic                          out_valid,
    output logic signed [DATA_WIDTH+15:0] out_data
);

    // Coeficientes do FIR (use os reais do seu projeto)
    logic signed [DATA_WIDTH-1:0] coeffs [0:TAP_NUM-1] = '{16'd1, 16'd2, 16'd3, 16'd4}; // Exemplo

    // Shift register de entrada
    logic signed [DATA_WIDTH-1:0] shift_reg [0:TAP_NUM-1];

    // Registradores intermediários para cada estágio
    logic signed [DATA_WIDTH*2-1:0] mult_stage [0:TAP_NUM-1];
    logic signed [DATA_WIDTH*2+3:0] sum_stage [0:TAP_NUM];  // Soma acumulada
    logic [TAP_NUM:0] valid_pipeline;

    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < TAP_NUM; i++) begin
                shift_reg[i]  <= '0;
                mult_stage[i] <= '0;
                sum_stage[i]  <= '0;
            end
            valid_pipeline <= '0;
        end else begin
            // Avança pipeline do valid
            valid_pipeline <= {valid_pipeline[TAP_NUM-1:0], in_valid};

            // Shift dos dados de entrada
            if (in_valid) begin
                shift_reg[0] <= in_data;
                for (i = 1; i < TAP_NUM; i++) begin
                    shift_reg[i] <= shift_reg[i-1];
                end
            end

            // Multiplicação por coeficientes
            for (i = 0; i < TAP_NUM; i++) begin
                mult_stage[i] <= shift_reg[i] * coeffs[i];
            end

            // Acúmulo (pipeline de soma)
            sum_stage[0] <= mult_stage[0];
            for (i = 1; i < TAP_NUM; i++) begin
                sum_stage[i] <= sum_stage[i-1] + mult_stage[i];
            end
        end
    end

    assign out_valid = valid_pipeline[TAP_NUM];  // O último estágio do pipeline indica a validade da saída
    assign out_data  = sum_stage[TAP_NUM-1] >>> 15;  // Último estágio da soma

endmodule
