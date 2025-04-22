module top (
    input logic clk,

    output logic [15:0] LED,

    input  logic mosi,
    output logic miso,
    input  logic sck,
    input  logic cs,

    input logic rst,

    output logic i2s_clk,  // Clock do I2S
    output logic i2s_ws,   // Word Select do I2S
    input  logic i2s_sd    // Dados do I2S
);

    logic [2:0] busy_sync;
    logic data_in_valid, busy, data_out_valid, busy_posedge;

    logic [ 7:0] spi_send_data;

    logic [23:0] pcm_out;
    logic [23:0] reduce_out;
    logic        pcm_ready;

    logic        rst_n;
    assign rst_n = ~rst;

    // Clock do microfone
    logic [4:0] counter;
    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (counter == 5'b11111) begin
                counter <= 0;
                i2s_clk <= ~i2s_clk;
            end else begin
                counter <= counter + 1;
            end
        end else begin
            counter <= 0;
            i2s_clk <= 1'b0;
        end
    end

    // Instanciação do módulo
    receiver_i2s #(
        .DATA_SIZE(24)
    ) u_i2s_receiver (
        .clk       (i2s_clk),
        .rst_n     (rst_n),
        .i2s_ws    (i2s_ws),
        .i2s_sd    (i2s_sd),
        .audio_data(pcm_out),
        .ready     (pcm_ready)
    );



    logic done_reduce;
    sample_reduce #(
        .DATA_SIZE(24),
        .REDUCE_FACTOR(24)
    ) u_sample_reduce (
        .clk           (i2s_clk),
        .rst_n         (rst_n),
        .ready_i2s     (pcm_ready),
        .audio_data_in (pcm_out),
        .done          (done_reduce),
        .audio_data_out(reduce_out)
    );

    SPI_Slave U1 (
        .clk  (clk),
        .rst_n(rst_n),

        .sck (sck),
        .cs  (cs),
        .mosi(mosi),
        .miso(miso),

        .data_in_valid (data_in_valid),
        .data_out_valid(data_out_valid),
        .busy          (busy),

        .data_in (spi_send_data),
        .data_out()
    );


    logic fifo_wr_en, fifo_rd_en, fifo_full, fifo_empty;
    logic [7:0] fifo_read_data, fifo_write_data;

    assign LED[0] = fifo_full;
    assign LED[1] = fifo_empty;

    FIFO #(
        .DEPTH(65536),  // 64kB
        .WIDTH(8)
    ) tx_fifo (
        .clk  (clk),
        .rst_n(rst_n),

        .wr_en_i(fifo_wr_en),
        .rd_en_i(fifo_rd_en),

        .write_data_i(fifo_write_data),
        .full_o      (fifo_full),
        .empty_o     (fifo_empty),
        .read_data_o (fifo_read_data)
    );

    logic [2:0] state_full;
    always_ff @(posedge clk) begin
        state_full <= {state_full[1:0], fifo_full};  // anterior atual tmp
    end

    logic posedge_full;
    assign posedge_full = ~state_full[2] & state_full[1];

    logic [5:0] full_count;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            full_count <= 6'b000000;
        end else if (posedge_full) begin
            full_count <= full_count + 1;
        end
    end

    assign LED[7:2] = full_count;

    typedef enum logic [1:0] {
        IDLE,
        WRITE_FIRST_BYTE,
        WRITE_SECOND_BYTE,
        WRITE_THIRD_BYTE
    } write_fifo_state_t;

    write_fifo_state_t        write_fifo_state;


    reg                [23:0] freeze_byte;

    // Estado do FIFO
    always_ff @(posedge clk) begin
        fifo_wr_en <= 1'b0;

        if (!rst_n) begin
            write_fifo_state <= IDLE;
            freeze_byte      <= 'b0;
        end else begin
            case (write_fifo_state)
                IDLE: begin
                    if (done_reduce_sync && !fifo_full) begin
                        freeze_byte      <= reduce_out;
                        fifo_write_data  <= reduce_out[7:0];
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

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            busy_sync <= 3'b000;
        end else begin
            busy_sync <= {busy_sync[1:0], busy};
        end
    end

    logic [2:0] done_sync;
    logic       done_reduce_sync;
    // Sincronização do done, para garantir que so é salvo uma vez na FIFO
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            done_sync <= 3'b000;
        end else begin
            done_sync <= {done_sync[1:0], done_reduce};
        end
    end
    assign done_reduce_sync = ~done_sync[2] & done_sync[1];

    logic write_back_fifo;

    // Leitura do FIFO
    always_ff @(posedge clk) begin
        fifo_rd_en <= 1'b0;

        if (!rst_n) begin
            data_in_valid   <= 1'b0;
            spi_send_data   <= 8'b0;
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

    assign busy_posedge = (busy_sync[2:1] == 2'b01) ? 1'b1 : 1'b0;
endmodule

