module receiver_i2s #(
    parameter int DATA_SIZE = 24
) (
    input  logic clk,
    input  logic rst_n,
    input  logic i2s_sd,
    output logic i2s_ws,
    output logic [DATA_SIZE-1:0] audio_data,
    output logic ready
);
    logic [$clog2(DATA_SIZE) + 1:0] bit_count = 0;

    logic i2s_ws_reg;
    assign i2s_ws = i2s_ws_reg;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            audio_data <= 0;
            bit_count <= 0;
            i2s_ws_reg <= 1'b0;
        end else begin
            if (bit_count == 0) begin
                bit_count <= bit_count + 1;
                ready <= 1'b0;
            end else if (bit_count <= DATA_SIZE) begin
                audio_data <= {audio_data[DATA_SIZE-2:0], i2s_sd};
                bit_count <= bit_count + 1;
            end else if (bit_count == 31) begin
                ready <= 1'b1;
                bit_count <= 0;
                i2s_ws_reg <= ~i2s_ws_reg;
            end else begin
                bit_count <= bit_count + 1;
            end
        end
    end
endmodule