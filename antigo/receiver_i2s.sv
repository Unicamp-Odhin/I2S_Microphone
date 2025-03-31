module receiver_i2s #(
    parameter int DATA_SIZE = 16 // Permite alterar para 8, 16, 24 ou 32
)(
    input  logic clk,
    input  logic rst_n,
    input  logic i2s_sd,
    output logic i2s_ws,
    output logic [DATA_SIZE-1:0] audio_data
    // output logic ready
);

    logic [DATA_SIZE-1:0] tmp_buffer;
    logic [$clog2(DATA_SIZE):0] bit_count;

    logic i2s_ws_reg;
    assign i2s_ws = i2s_ws_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i2s_ws_reg <= 1'b0;
        end else if (bit_count == DATA_SIZE) begin
            i2s_ws_reg <= ~i2s_ws_reg; 
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tmp_buffer <= '0;
            bit_count <= 0;
            ready <= 1'b0;
        end else begin
            if (bit_count < DATA_SIZE) begin
                tmp_buffer <= {tmp_buffer[DATA_SIZE-2:0], i2s_sd};
                bit_count <= bit_count + 1;
                ready <= 1'b0;
            end else begin
                bit_count <= 0;
                ready <= 1'b1;
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if (ready) begin
            audio_data <= tmp_buffer;
        end
    end
    
endmodule