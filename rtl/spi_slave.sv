module SPI_Slave #(
    parameter SPI_BITS_PER_WORD = 8
)(
    input logic clk,
    input logic rst_n,

    input  logic sck,
    input  logic cs,
    input  logic mosi,
    output logic miso,
    
    input  logic data_in_valid,
    output logic data_out_valid,
    output logic busy,

    input  logic [SPI_BITS_PER_WORD-1:0] data_in,
    output logic [SPI_BITS_PER_WORD-1:0] data_out
);


logic [SPI_BITS_PER_WORD-1:0] data_in_reg, data_to_send;
logic [2:0] bit_count;
logic [2:0] sck_sync, cs_sync; // 3-bit shift register to slk and cs sync
logic [1:0] mosi_sync;
logic rising_edge, falling_edge, cs_active, start_message, end_message;

always_ff @(posedge clk ) begin
    if(!rst_n) begin
        sck_sync  <= 3'b000;
        cs_sync   <= 3'b000;
        mosi_sync <= 2'b00;
    end else begin
        sck_sync  <= {sck_sync[1:0], sck};
        cs_sync   <= {cs_sync[1:0], cs};
        mosi_sync <= {mosi_sync[0], mosi};
    end
end

always_ff @(posedge clk ) begin
    if(!cs_active) begin
        bit_count <= 3'b000;
    end else begin
        if(rising_edge) begin
            bit_count <= bit_count + 1'b1;
            data_out <= {data_out[6:0], mosi_sync[1]};
        end    
    end

    if(start_message) begin
        busy <= 1'b0;
    end

    if(end_message) begin
        busy <= 1'b1;
    end
end

always_ff @(posedge clk ) begin
    if(!rst_n) begin
        data_out_valid <= 1'b0;
    end else begin
        data_out_valid <= cs_active && rising_edge && &bit_count;
    end
end

always_ff @(posedge clk ) begin
    if(!rst_n) begin
        data_in_reg <= 8'h00;
    end else begin
        if(data_in_valid) begin
            data_in_reg <= data_in;
        end
    end
end

always_ff @(posedge clk ) begin
    if(cs_active) begin
        if(start_message) begin
            data_to_send <= data_in_reg;
        end else begin
            if(rising_edge) begin
                data_to_send <= {data_to_send[6:0], 1'b0};
            end
        end
    end
end

assign miso          = data_to_send[7];
assign rising_edge   = ~sck_sync[2] & sck_sync[1]; // SCK rising edge
assign falling_edge  = ~sck_sync[1] & sck_sync[2]; // SCK falling edge
assign cs_active     = ~cs_sync[1];
assign start_message = ~cs_sync[1] & cs_sync[2]; // message starts in cs falling edge
assign end_message   = ~cs_sync[2] & cs_sync[1]; // message ends in cs rising edge

endmodule