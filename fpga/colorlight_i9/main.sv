module main (
    input logic clk,  // board clock 25mhz 

    input  logic M_DATA,     // microfone data
    output logic M_CLK = 0,  // microfone clock
    output logic M_LRSEL,    // Left/Right Select

    input  logic cs,    // enable spi
    input  logic mosi,
    input  logic sck,
    output logic miso,

    output logic [15:0] pcm_out,
    output logic        pcm_ready,
    input  logic        rst_n,

    output logic [7:0] LED
);

    logic [2:0] busy_sync;
    logic data_in_valid, busy, data_out_valid, busy_posedge;

    logic [7:0] spi_send_data;

    // logic [15:0] pcm_out;
    // logic pcm_ready;

    // logic rst_n;
    // assign rst_n = 1'b1;

    // Clock do microfone
    logic [2:0] counter;
    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (counter == 3'b111) begin
                counter <= 0;
                M_CLK   <= ~M_CLK;
            end else begin
                counter <= counter + 1;
            end
        end else begin
            counter <= 0;
            M_CLK   <= 1'b0;
        end
    end

    // Instanciação do módulo
    receiver_i2s #(
        .DATA_SIZE(16)
    ) u_i2s_receiver (
        .clk       (M_CLK),
        .rst_n     (rst_n),
        .i2s_ws    (M_LRSEL),
        .i2s_sd    (M_DATA),
        .audio_data(pcm_out),
        .ready     (pcm_ready)
    );

    // LEDS
    leds u_leds (
        .clk    (clk),
        .data_in(pcm_out),
        .led    (LED)
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

    FIFO #(
        .DEPTH(32768),  // 16kB
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

    typedef enum logic [1:0] {
        IDLE,
        WRITE_FIRST_BYTE,
        WRITE_SECOND_BYTE
    } write_fifo_state_t;

    write_fifo_state_t write_fifo_state;


    // Estado do FIFO
    always_ff @(posedge clk) begin
        fifo_wr_en <= 1'b0;

        if (!rst_n) begin
            write_fifo_state <= IDLE;
        end else begin
            // unique case (write_fifo_state)
            case (write_fifo_state)
                IDLE: begin
                    if (pcm_ready && !fifo_full) begin
                        fifo_write_data  <= pcm_out[7:0];
                        fifo_wr_en       <= 1'b1;
                        write_fifo_state <= WRITE_FIRST_BYTE;
                    end
                end
                WRITE_FIRST_BYTE: begin
                    if (!fifo_full) begin
                        fifo_write_data  <= pcm_out[15:8];
                        fifo_wr_en       <= 1'b1;
                        write_fifo_state <= WRITE_SECOND_BYTE;
                    end else begin
                        fifo_wr_en <= 1'b0;
                    end
                end
                WRITE_SECOND_BYTE: begin
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
                    spi_send_data <= 8'b0;
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

