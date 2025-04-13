module receiver_i2s #(
    parameter int DATA_SIZE    = 24,
    parameter int CLK_FREQ     = 100_000_000,
    parameter int I2S_CLK_FREQ = 3_072_000
) (
    input  logic                   clk,
    input  logic                   rst_n,

    input  logic                   i2s_sd,
    output logic                   i2s_ws,
    output logic                   i2s_clk,

    output logic [DATA_SIZE - 1:0] audio_data,
    output logic                   ready
);

    localparam PDM_CLK_PERIOD   = CLK_FREQ / I2S_CLK_FREQ;
    localparam LAST_BIT_COUNTER = $clog2(PDM_CLK_PERIOD);

    logic [LAST_BIT_COUNTER:0] clk_counter;
    logic i2s_posedge;
    logic [1:0] edge_counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i2s_clk      <= 0;
            clk_counter  <= 0;
            edge_counter <= 0;
        end else begin
            if (clk_counter >= (PDM_CLK_PERIOD / 2)) begin
                i2s_clk <= ~i2s_clk;
                clk_counter <= 0;
            end else begin
                clk_counter <= clk_counter + 1;
            end

            edge_counter <= {edge_counter[0], i2s_clk};
        end
    end

    assign i2s_posedge = ~edge_counter[1] & edge_counter[0];

    typedef enum logic [1:0] { 
        IGNORE_FIRST_BIT,
        READ_WORD,
        IGNORE_TRISTATE,
        IGNORE_SECOND_WORD
    } read_i2s_state_t;

    read_i2s_state_t read_i2s_state;

    logic [31:0] word_counter;

    always_ff @( posedge clk or negedge rst_n ) begin
        ready <= 1'b0;

        if (!rst_n) begin
            read_i2s_state <= IGNORE_FIRST_BIT;
            audio_data     <= 'd0;
            ready          <= 1'b0;
            word_counter   <= 'd0;
            i2s_ws         <= 1'b0;
        end else begin
            case (read_i2s_state)
                IGNORE_FIRST_BIT: begin
                    if (i2s_posedge) begin
                        read_i2s_state <= READ_WORD;
                        word_counter   <= word_counter + 1;
                    end
                end

                READ_WORD: begin
                    if (i2s_posedge) begin
                        audio_data   <= {audio_data[DATA_SIZE - 2:0], i2s_sd};
                        word_counter <= word_counter + 1;
                        if (word_counter == DATA_SIZE) begin
                            read_i2s_state <= IGNORE_TRISTATE;
                        end
                    end
                end

                IGNORE_TRISTATE: begin
                    if (i2s_posedge) begin
                        word_counter <= word_counter + 1;
                        if(word_counter == 31) begin
                            word_counter <= 0;
                            i2s_ws       <= 1;
                            read_i2s_state <= IGNORE_SECOND_WORD;
                        end
                    end
                end

                IGNORE_SECOND_WORD: begin
                    if (i2s_posedge) begin
                        word_counter <= word_counter + 1;
                        if (word_counter == 31) begin
                            word_counter   <= 0;
                            i2s_ws         <= 0;
                            ready          <= 1'b1;
                            read_i2s_state <= IGNORE_FIRST_BIT;
                        end
                    end
                end

                default: read_i2s_state <= IGNORE_FIRST_BIT;
            endcase
        end
        
    end

endmodule