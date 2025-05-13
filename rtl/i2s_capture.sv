module i2s_capture #(
    parameter int DATA_SIZE    = 24,
    parameter int CLK_FREQ     = 100_000_000,  // Frequência do clock do sistema
    parameter int I2S_CLK_FREQ = 1_500_000
) (
    input  logic                 clk,         // 1.5MHz
    input  logic                 rst_n,
    
    output logic                 i2s_clk,
    input  logic                 i2s_sd,
    output logic                 i2s_ws,
    
    output logic [DATA_SIZE-1:0] audio_data,
    output logic                 ready
);
    // Geração de clock I2S de aproximadamente 1,5 MHz a partir de CLK_FREQ (ex: 100 MHz)
    // Justificativa: Para gerar 1,5 MHz, precisamos de um clock que oscile (toggle) a cada (CLK_FREQ / (2 * 1_500_000)) ciclos
    // pois cada ciclo completo de clock exige dois toggles (subida e descida)

    localparam integer CLK_DIV      = CLK_FREQ / (2 * I2S_CLK_FREQ); // Divisor para obter 1,5 MHz
    localparam integer COUNTER_SIZE = $clog2(CLK_DIV);         // Tamanho necessário para representar o divisor

    logic [COUNTER_SIZE-1:0] counter;

    logic i2s_posedge;
    logic [2:0] edge_counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter      <= 0;
            i2s_clk      <= 0;
            edge_counter <= 0;
        end else begin
            if (counter == CLK_DIV - 1) begin
                counter <= 0;
                i2s_clk <= ~i2s_clk;
            end else begin
                counter <= counter + 1;
            end

            edge_counter <= {edge_counter[1:0], i2s_clk};
        end
    end

    assign i2s_posedge = !edge_counter[2] & edge_counter[1];


    logic [8:0] bit_count;

    logic  i2s_ws_reg;
    assign i2s_ws = i2s_ws_reg;

    // Essa lógica demora 64 ciclos de clock para fazer a leitura do dado, logo
    // a taxa de amostragem é 24414Hz
    always_ff @(posedge clk or negedge rst_n) begin
        ready <= 1'b0;

        if (!rst_n) begin
            audio_data <= '0;
            bit_count  <= '0;
            i2s_ws_reg <= 1'b0;
        end else if(i2s_posedge) begin
            if (bit_count == 0) begin
                audio_data <= '0;
                bit_count  <= bit_count + 1;
            end else if (bit_count <= DATA_SIZE) begin
                audio_data <= {audio_data[DATA_SIZE-2:0], i2s_sd};
                bit_count  <= bit_count + 1;
            end else if (bit_count == 31) begin
                ready      <= 1'b1;
                i2s_ws_reg <= 1;
                bit_count  <= bit_count + 1;
            end else if (bit_count == 63) begin
                bit_count  <= 0;
                i2s_ws_reg <= 0;
            end else begin
                bit_count <= bit_count + 1;
            end
        end
    end
endmodule
