module leds(
    input  logic clk,         // board clock 25MHz 
    input  logic [23:0] data_in,
    output logic [7:0] led
);

    logic [31:0] counter2;
    logic clk2;
    logic [15:0] temp_led;
    logic [7:0] compact_led;
    
    // assign temp_led = (data_in[15] == 1'b1) ? (data_in + 16'h8000) : ((data_in + 16'h7FFF) & 16'h7FFF);

    // assign compact_led[7] = temp_led[15] | temp_led[14];
    // assign compact_led[6] = temp_led[13] | temp_led[12];
    // assign compact_led[5] = temp_led[11] | temp_led[10];
    // assign compact_led[4] = temp_led[9]  | temp_led[8];
    // assign compact_led[3] = temp_led[7]  | temp_led[6];
    // assign compact_led[2] = temp_led[5]  | temp_led[4];
    // assign compact_led[1] = temp_led[3]  | temp_led[2];
    // assign compact_led[0] = temp_led[1]  | temp_led[0];

    always_ff @(posedge clk) begin
        if (counter2 == 32'd12000000) begin
            counter2 <= 32'b0;
            clk2 <= ~clk2;
        end else begin
            counter2 <= counter2 + 32'b1;
        end
    end

    // always_ff @(posedge clk2) begin
    //     case (compact_led)
    //         8'b1???????: led <= 8'b11111111;
    //         8'b01??????: led <= 8'b01111111;
    //         8'b001?????: led <= 8'b00111111;
    //         8'b0001????: led <= 8'b00001111;
    //         8'b00001???: led <= 8'b00011111;
    //         8'b000001??: led <= 8'b00000111;
    //         8'b0000001?: led <= 8'b00000011;
    //         8'b00000001: led <= 8'b00000001;
    //         default:     led <= 8'b00000000;
    //     endcase
    // end

    assign led = data_in[23:15]; // Teste de LEDS

endmodule