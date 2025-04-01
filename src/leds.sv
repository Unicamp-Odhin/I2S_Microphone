module leds (
    input  logic clk,         // board clock 25mhz 
    input  logic [15:0] data_in,
    output logic [7:0] led
);

    logic [32:0] counter2;
    logic clk2;
    always_ff @(posedge clk) begin
        if (counter2 == 32'd3000000) begin
            counter2 <= 0;
            clk2 <= ~clk2;
        end else begin
            counter2 <= counter2 + 1;
        end
    end

    logic [7:0] audio;
    assign audio = {
        data_in[15] | data_in[14],
        data_in[13] | data_in[12],
        data_in[11] | data_in[10],
        data_in[9]  | data_in[8],
        data_in[7]  | data_in[6],
        data_in[5]  | data_in[4],
        data_in[3]  | data_in[2],
        data_in[1]  | data_in[0]
    };

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

endmodule