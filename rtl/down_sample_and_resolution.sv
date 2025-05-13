module down_sample_and_resolution #(
    parameter int DATA_IN_WIDTH     = 16,
    parameter int DATA_OUT_WIDTH    = 8,
    parameter int DECIMATION_FACTOR = 2
) (
    input  logic clk,
    input  logic rst_n,

    input  logic valid_in,
    input  logic [DATA_IN_WIDTH - 1:0] data_in,

    output logic valid_out,
    output logic [DATA_OUT_WIDTH - 1:0] data_out
);
    localparam RESOLUTION_DIV_SHIFT  = DATA_IN_WIDTH - DATA_OUT_WIDTH;
    localparam VALUE_SUM_TO_UNSIGNED = 2**(DATA_IN_WIDTH - 1);
    localparam NUM_BITS_TO_EXTEND    = 32 - DATA_IN_WIDTH;

    logic [31:0] acc;
    logic [$clog2(DECIMATION_FACTOR):0] counter;
    logic valid_acc;

    logic [DATA_IN_WIDTH:0] acc_out;
    logic valid_acc_out;

    always_ff @(posedge clk ) begin
        if(!rst_n) begin
            acc           <= 0;
            counter       <= 0;
            valid_acc_out <= 0;
            acc_out       <= 0;
        end else begin
            if(valid_in) begin
                acc     <= acc + {{NUM_BITS_TO_EXTEND{data_in[DATA_IN_WIDTH - 1]}}, data_in};
                counter <= counter + 1;
            end

            if(counter == DECIMATION_FACTOR) begin
                acc_out       <= acc >>> $clog2(DECIMATION_FACTOR);
                valid_acc_out <= 1;
                acc           <= 0;
                counter       <= 0;
            end else begin
                valid_acc_out <= 0;
            end
        end
    end

    logic [DATA_IN_WIDTH:0] product;
    logic valid_product;

    always_ff @(posedge clk) begin
        valid_out <= 0;

        if(!rst_n) begin
            data_out      <= 0;
            valid_out     <= 0;
            product       <= 0;
            valid_product <= 0;
        end else begin
            valid_product <= valid_acc_out;
            product       <= acc_out + VALUE_SUM_TO_UNSIGNED; //  Desloca o intervalo de [-32768, +32767] para [0, 65535], removendo o sinal
            valid_out     <= valid_product;
            data_out      <= product >> RESOLUTION_DIV_SHIFT; // Divide por 8
        end
    end

endmodule

