module receiver_i2s_board (
    input logic clk,
    input logic SD,
    output logic WS,
    output logic SCK,
    output logic LED0, LED1, LED2, LED3, LED4, LED5, LED6, LED7
);
    logic [15:0] audio_data;
    logic rst = 1'b0;

    logic [2:0] counter;
    always_ff @(posedge clk) begin
        if (counter == 3'b0) begin
            counter <= 0;
            SCK <= ~SCK;
        end else begin
            counter <= counter + 1;
        end
    end

    logic [32:0] counter2;
    logic clk2;
    always_ff @(posedge clk) begin
        if (counter2 == 32'd1200000) begin
            counter2 <= 0;
            clk2 <= ~clk2;
        end else begin
            counter2 <= counter2 + 1;
        end
    end

    logic [7:0] audio;
    assign audio = {
        audio_data[15] | audio_data[14],
        audio_data[13] | audio_data[12],
        audio_data[11] | audio_data[10],
        audio_data[9]  | audio_data[8],
        audio_data[7]  | audio_data[6],
        audio_data[5]  | audio_data[4],
        audio_data[3]  | audio_data[2],
        audio_data[1]  | audio_data[0]
    };

    logic [7:0] led;
    assign {LED7, LED6, LED5, LED4, LED3, LED2, LED1, LED0} = led;
    always_ff @(posedge clk2) begin
        casez (audio)
            8'b???????1: led <= ~8'b11111111;
            8'b??????10: led <= ~8'b11111110;
            8'b?????100: led <= ~8'b11111100;
            8'b????1000: led <= ~8'b11111000;
            8'b???10000: led <= ~8'b11110000;
            8'b??100000: led <= ~8'b11100000;
            8'b?1000000: led <= ~8'b11000000;
            8'b10000000: led <= ~8'b10000000;
            default:     led <= ~8'b00000000;
        endcase
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