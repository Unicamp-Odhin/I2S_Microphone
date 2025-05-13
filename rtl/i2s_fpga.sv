module i2s_fpga #(
    parameter int DATA_SIZE       = 24,
    parameter int REDUCE_FACTOR   = 2,
    parameter int FIFO_DEPTH      = 128 * 1024, // 128kB
    parameter int FIFO_WIDTH      = 8,
    parameter int CLK_FREQ        = 100_000_000,  // Frequência do clock do sistema
    parameter int SIZE_FULL_COUNT = 6,
    parameter int I2S_CLK_FREQ    = 1_500_000
) (
    input  logic clk,
    input  logic rst_n,

    input  logic mosi,
    output logic miso,
    input  logic cs,
    input  logic sck,

    output logic i2s_clk,
    output logic i2s_ws,
    input  logic i2s_sd,

    output logic [SIZE_FULL_COUNT-1:0] full_count,
    output logic fifo_empty,
    output logic fifo_full

);
    logic [2:0] busy_sync;
    logic data_in_valid, busy, data_out_valid, busy_posedge;

    logic [7:0] spi_send_data;

    logic pcm_ready;
    logic [23:0] pcm_out;

    I2S #(
        .DATA_OUT_SIZE (16),
        .I2S_DATA_SIZE (DATA_SIZE),
        .CLK_FREQ      (CLK_FREQ),
        .I2S_CLK_FREQ  (I2S_CLK_FREQ),
        .REDUCE_FACTOR (REDUCE_FACTOR) 
    ) u_i2s (
        .clk       (clk),
        .rst_n     (rst_n),
        
        .i2s_clk   (i2s_clk),
        .i2s_ws    (i2s_ws),
        .i2s_sd    (i2s_sd),
        
        .pcm_out   (pcm_out),
        .pcm_ready (pcm_ready)  // A cada 24_414Hz
    );


    SPI_Slave #(
        .SPI_BITS_PER_WORD (8),
        .SPI_MODE          (0)
    ) U1 (
        .clk            (clk),
        .rst_n          (rst_n),

        .sck            (sck),
        .cs             (cs),
        .mosi           (mosi),
        .miso           (miso),

        .data_in_valid  (data_in_valid),
        .data_out_valid (data_out_valid),
        .busy           (busy),

        .data_in        (spi_send_data),
        .data_out       ()
    );


    logic fifo_wr_en, fifo_rd_en;
    logic [7:0] fifo_read_data, fifo_write_data;

    FIFO #(
        .DEPTH (FIFO_DEPTH),  // 128kb
        .WIDTH (FIFO_WIDTH)
    ) tx_fifo (
        .clk          (clk),
        .rst_n        (rst_n),

        .wr_en_i      (fifo_wr_en),
        .rd_en_i      (fifo_rd_en),

        .write_data_i (fifo_write_data),
        .full_o       (fifo_full),
        .empty_o      (fifo_empty),
        .read_data_o  (fifo_read_data)
    );

    logic [2:0] state_full;
    always_ff @(posedge clk) begin
        state_full <= {state_full[1:0], fifo_full};  // anterior atual tmp
    end

    logic posedge_full;
    assign posedge_full = ~state_full[2] & state_full[1];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            full_count <= '0;
        end else if (posedge_full) begin
            full_count <= full_count + 1;
        end
    end

    // Sinal usado para garantir que a palavra seja escrita na FIFO
    // e não que haja bytes de multiplas amostras sendo escritos
    // na mesma palavra na FIFO
    logic [23:0] freeze_byte;

    typedef enum logic [1:0] {
        IDLE,
        WRITE_FIRST_BYTE,
        WRITE_SECOND_BYTE,
        WRITE_THIRD_BYTE
    } write_fifo_state_t;

    write_fifo_state_t write_fifo_state;

    // Estado do FIFO, pode guardar os 3 bytes, mas por questão de economia de espaço
    // irei ignorar o byte menos significativo
    always_ff @(posedge clk) begin
        fifo_wr_en <= 1'b0;

        if (!rst_n) begin
            write_fifo_state <= IDLE;
            freeze_byte      <= '0;
        end else begin
            case (write_fifo_state)
                IDLE: begin
                    if (pcm_ready && !fifo_full) begin
                        freeze_byte      <= pcm_out;
                        fifo_write_data  <= pcm_out[7:0];
                        fifo_wr_en       <= 1'b1;
                        write_fifo_state <= WRITE_FIRST_BYTE;
                    end else begin
                        fifo_wr_en <= 1'b0;
                    end
                end
                WRITE_FIRST_BYTE: begin
                    if (!fifo_full) begin
                        fifo_write_data  <= freeze_byte[15:8];
                        fifo_wr_en       <= 1'b1;
                        write_fifo_state <= WRITE_SECOND_BYTE;
                    end else begin
                        fifo_wr_en <= 1'b0;
                    end
                end
                WRITE_SECOND_BYTE: begin
                    if (!fifo_full) begin
                        fifo_write_data  <= freeze_byte[23:16];
                        fifo_wr_en       <= 1'b1;
                        write_fifo_state <= WRITE_THIRD_BYTE;
                    end else begin
                        fifo_wr_en <= 1'b0;
                    end
                end
                WRITE_THIRD_BYTE: begin
                    write_fifo_state <= IDLE;
                end
                default: write_fifo_state <= IDLE;
            endcase
        end
    end

    logic write_back_fifo;

    // Leitura do FIFO
    always_ff @(posedge clk) begin
        fifo_rd_en <= 1'b0;

        if (!rst_n) begin
            data_in_valid   <= 1'b0;
            spi_send_data   <= '0;
            write_back_fifo <= 1'b0;
        end else begin
            if (busy_posedge) begin
                if (fifo_empty) begin
                    data_in_valid <= 1'b1;
                end else begin
                    fifo_rd_en      <= 1'b1;
                    write_back_fifo <= 1'b1;
                end
            end else begin
                data_in_valid <= 1'b0;
            end

            if (write_back_fifo) begin
                fifo_rd_en      <= 1'b0;
                write_back_fifo <= 1'b0;
                spi_send_data   <= fifo_read_data;
                data_in_valid   <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            busy_sync <= 3'b000;
        end else begin
            busy_sync <= {busy_sync[1:0], busy};
        end
    end

    assign busy_posedge = (busy_sync[2:1] == 2'b01) ? 1'b1 : 1'b0;

endmodule
