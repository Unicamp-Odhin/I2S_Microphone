module sample_reduce #(
    parameter int DATA_SIZE     = 24,
    parameter int REDUCE_FACTOR = 4
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 ready_i2s,
    input  logic [DATA_SIZE-1:0] audio_data_in,

    output logic                 done,
    output logic [DATA_SIZE-1:0] audio_data_out
);

    logic [31:0] counter;

    always_ff @(posedge clk or negedge rst_n) begin
        done <= 0;

        if (!rst_n) begin
            counter        <= '0;
            audio_data_out <= '0;
        end else begin
            if (ready_i2s) begin
                if (counter == REDUCE_FACTOR - 1) begin
                    counter        <= '0;
                    done           <= 1;
                    audio_data_out <= audio_data_in;
                end else begin
                    counter <= counter + 1;
                end
            end
        end
    end
endmodule
