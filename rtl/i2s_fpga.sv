module i2s_fpga #(
    parameter int DATA_SIZE = 24,
    parameter int REDUCE_FACTOR = 2,
    parameter int FIFO_DEPTH = 128 * 1024, // 128kB
    parameter int FIFO_WIDTH = 8,
    parameter int CLK_FREQ = 100_000_000,  // Frequência do clock do sistema
    parameter int SIZE_FULL_COUNT = 6
) (
    input logic clk,
    input logic rst,
    input logic mosi,
    output logic miso,
    input logic cs,
    input logic sck,

    output logic i2s_clk,
    output logic i2s_ws,
    input logic i2s_sd,

    output logic [SIZE_FULL_COUNT-1:0] full_count,
    output logic fifo_empty,
    output logic fifo_full

);
    logic [2:0] busy_sync;
    logic data_in_valid, busy, data_out_valid, busy_posedge;

    logic [7:0] spi_send_data;

    logic       pcm_ready;

    logic       rst_n;
    assign rst_n = ~rst;

    // Geração de clock I2S de aproximadamente 1,5 MHz a partir de CLK_FREQ (ex: 100 MHz)
    // Justificativa: Para gerar 1,5 MHz, precisamos de um clock que oscile (toggle) a cada (CLK_FREQ / (2 * 1_500_000)) ciclos
    // pois cada ciclo completo de clock exige dois toggles (subida e descida)

    parameter real TARGET_FREQ = 1_500_000;
    parameter integer CLK_DIV = CLK_FREQ / (2 * TARGET_FREQ); // Divisor para obter 1,5 MHz
    parameter integer COUNTER_SIZE = $clog2(CLK_DIV);         // Tamanho necessário para representar o divisor

    logic [COUNTER_SIZE-1:0] counter = 0;
    logic i2s_clk_reg = 0;
    assign i2s_clk = i2s_clk_reg;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            counter <= 0;
            i2s_clk_reg <= 0;
        end else begin
            if (counter == CLK_DIV - 1) begin
                counter <= 0;
                i2s_clk_reg <= ~i2s_clk_reg;
            end else begin
                counter <= counter + 1;
            end
        end
    end


    logic [23:0] pcm_out;

    // Instanciação do módulo
    i2s_capture #(
        .DATA_SIZE(DATA_SIZE)
    ) u_i2s_receiver (
        .clk       (i2s_clk),
        .rst_n     (rst_n),
        .i2s_ws    (i2s_ws),
        .i2s_sd    (i2s_sd),
        .audio_data(pcm_out),
        .ready     (pcm_ready)  // A cada 24_414Hz
    );


    logic [23:0] reduce_out;


    // Para estimar o tempo necessário até a memória FIFO encher completamente:
    //
    // 1. Determine o tamanho de cada amostra em bytes (nesse caso: 3 bytes por amostra).
    // 2. Calcule a taxa efetiva de amostragem 
    //                                         (nesse caso: 24.414 Hz / REDUCE_FACTOR ≈ 12 kHz).
    // 3. Multiplique o tamanho da amostra pela taxa de amostragem para obter a taxa de dados 
    //                                         (nesse caso: 2 bytes * 12KHz = 24 kB/s).
    // 4. Divida a capacidade total da FIFO (em bytes) pela taxa de dados para obter o tempo até encher:
    //                                          tempo ≈ capacidade_da_FIFO / taxa_de_dados
    //                                          nesse caso: 64 kB / 24 kB/s ≈ 2.66 segundos

    logic        done_reduce;
    sample_reduce #(
        .DATA_SIZE(DATA_SIZE),
        .REDUCE_FACTOR(REDUCE_FACTOR)  // 24_414Hz / REDUCE_FACTOR gera a nova taxa de amostragem
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


    logic fifo_wr_en, fifo_rd_en;
    logic [7:0] fifo_read_data, fifo_write_data;

    FIFO #(
        .DEPTH(FIFO_DEPTH),  // 128kb
        .WIDTH(FIFO_WIDTH)
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

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            full_count <= '0;
        end else if (posedge_full) begin
            full_count <= full_count + 1;
        end
    end

    write_fifo_state_t        write_fifo_state;

    logic                     done_reduce_sync;
    logic              [ 2:0] done_sync;

    // Sinal usado para garantir que a palavra seja escrita na FIFO
    // e não que haja bytes de multiplas amostras sendo escritos
    // na mesma palavra na FIFO
    logic              [23:0] freeze_byte;

    // Sincronização do done, para garantir que so é salvo uma vez na FIFO
    // e o controle da frequencia de escrita da palavra de sincronização na FIFO
    parameter FREQUENCY_SINC = 127;
    logic [$clog2(FREQUENCY_SINC):0] counter_write_fifo;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            counter_write_fifo <= 8'b0;
            done_sync          <= 3'b000;
        end else begin
            if (counter_write_fifo == FREQUENCY_SINC - 1) begin
                done_sync          <= {done_sync[1:0], done_reduce};
                counter_write_fifo <= 8'b0;
            end else begin
                done_sync          <= {done_sync[1:0], done_reduce};
                counter_write_fifo <= counter_write_fifo + 1;
            end
        end
    end

    // O done_sync é usado para garantir que o done seja salvo apenas uma vez na FIFO
    assign done_reduce_sync = ~done_sync[2] & done_sync[1];

    // Para garantir um byte periódico para sincronização do spi
    // Isso é usado no código hex2wav_sinc.cpp para conseguir determinar se houve algum erro de leitura
    logic [23:0] write_fifo;
    assign write_fifo = ~|(counter_write_fifo % (FREQUENCY_SINC - 1)) ? 24'hAAFF00 : reduce_out;


    typedef enum logic [1:0] {
        IDLE,
        WRITE_FIRST_BYTE,
        WRITE_SECOND_BYTE,
        WRITE_THIRD_BYTE
    } write_fifo_state_t;

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
                    if (done_reduce_sync && !fifo_full) begin
                        freeze_byte      <= write_fifo;
                        fifo_write_data  <= write_fifo[15:8];
                        fifo_wr_en       <= 1'b1;
                        write_fifo_state <= WRITE_FIRST_BYTE;
                    end else begin
                        fifo_wr_en <= 1'b0;
                    end
                end
                WRITE_FIRST_BYTE: begin
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
