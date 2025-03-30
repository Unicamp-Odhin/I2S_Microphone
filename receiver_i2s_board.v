module receiver_i2s_board (
    input wire clk,
    input wire SD,
    output wire WS,
    output reg SCK, 
);
    wire [15:0] audio_data;
    wire rst = 1'b0; 

    reg [2:0] counter;
    always @(posedge clk) begin
        if (counter == 3'b0) begin
            counter <= 0;
            SCK <= ~SCK;
        end else begin
            counter <= counter + 1;
        end
    end

    receiver_i2s #(
        .DATA_SIZE(16)
    ) i2s_receiver (
        .clk(SCK),
        .rst(rst),
        .i2s_ws(WS),
        .i2s_sd(SD),
        .audio_data(audio_data)
    );
endmodule