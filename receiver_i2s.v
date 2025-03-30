module receiver_i2s #(
    parameter DATA_SIZE = 16 // Permite alterar para 8, 16, 24 ou 32
)(
    input wire clk,
    input wire rst,
    input wire i2s_sd,
    output wire i2s_ws,
    output reg [DATA_SIZE-1:0] audio_data
);

    reg [DATA_SIZE-1:0] tmp_buffer;
    reg [$clog2(DATA_SIZE):0] bit_count;

    reg i2s_ws_reg;
    assign i2s_ws = i2s_ws_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            i2s_ws_reg <= 1'b0;
        end else if (bit_count == DATA_SIZE) begin
            i2s_ws_reg <= ~i2s_ws_reg; // Toggle i2s_ws after DATA_SIZE bits
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tmp_buffer <= {DATA_SIZE{1'b0}};
            bit_count <= 0;
        end else begin
            if (bit_count < DATA_SIZE) begin
                tmp_buffer <= {tmp_buffer[DATA_SIZE-2:0], i2s_sd};
                bit_count <= bit_count + 1;
            end else begin
                audio_data <= tmp_buffer;
                bit_count <= 0;
            end
        end
    end
    
endmodule