module receiver_i2s #(
    parameter int DATA_SIZE = 16 // Permite alterar para 8, 16, 24 ou 32
)(
    input  logic clk,
    input  logic rst_n,
    input  logic i2s_sd,
    output logic i2s_ws,
    output logic [DATA_SIZE-1:0] audio_data,
    output logic ready
);

    logic sample_ready;
    logic [2*DATA_SIZE-1:0] accumulator;
    logic [DATA_SIZE-1:0] i2s_data;

    logic [DATA_SIZE-1:0] tmp_buffer;
    logic [$clog2(DATA_SIZE) + 1:0] bit_count = 0;

    logic [1:0] sample_counter;

    logic i2s_ws_reg = 0;
    assign i2s_ws = i2s_ws_reg;

    always_ff @(negedge clk) begin
        if (!rst_n) begin
            i2s_ws_reg <= 1'b0;
        end else begin
            if (sample_ready) begin
                i2s_ws_reg <= ~i2s_ws_reg;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            accumulator <= 0;
            audio_data  <= 0;
            ready       <= 1'b0;
            sample_counter <= 0;
        end else begin
            if (sample_ready) begin
                sample_counter <= sample_counter + 1;
                accumulator <= accumulator + i2s_data;
            end

            if(&sample_counter) begin
                audio_data <= accumulator[17:2];
                ready <= 1'b1;
                accumulator <= 0;
                sample_counter <= 0;
            end
        end
    end


    // geralemente com o bit mais significativo primeiro
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            tmp_buffer <= 0;
            bit_count <= 0;
            i2s_data <= 0;
            sample_ready <= 1'b0;
        end else begin
            if (bit_count < DATA_SIZE) begin
                tmp_buffer <= {tmp_buffer[DATA_SIZE-2:0], i2s_sd};
                bit_count <= bit_count + 1;
                sample_ready <= 1'b0;
            end else begin
                bit_count <= 0;
                i2s_data <= tmp_buffer;
                sample_ready <= 1'b1;
            end
        end
    end
endmodule