module receiver_i2s #(
    parameter int DATA_SIZE = 24
) (
    input  logic                 clk,         // 1.5MHz
    input  logic                 rst_n,
    input  logic                 i2s_sd,
    output logic                 i2s_ws,
    output logic [DATA_SIZE-1:0] audio_data,
    output logic                 ready
);
    logic [8:0] bit_count = 0;

    logic       i2s_ws_reg;
    assign i2s_ws = i2s_ws_reg;

    // Essa lógica demora 64 ciclos de clock para fazer a leitura do dado, logo
    // a taxa de amostragem é 24414Hz
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ready      <= 1'b0;
            audio_data <= '0;
            bit_count  <= '0;
            i2s_ws_reg <= 1'b0;
        end else begin
            if (bit_count == 0) begin
                ready      <= 1'b0;
                audio_data <= '0;
                bit_count  <= bit_count + 1;
            end else if (bit_count <= DATA_SIZE) begin
                ready      <= 1'b0;
                audio_data <= {audio_data[DATA_SIZE-2:0], i2s_sd};
                bit_count  <= bit_count + 1;
            end else if (bit_count == 31) begin
                ready      <= 1'b1;
                i2s_ws_reg <= 1;
                bit_count  <= bit_count + 1;
            end else if (bit_count == 63) begin
                ready      <= 1'b0;
                bit_count  <= 0;
                i2s_ws_reg <= 0;
            end else begin
                ready     <= 1'b0;
                bit_count <= bit_count + 1;
            end
        end
    end
endmodule
