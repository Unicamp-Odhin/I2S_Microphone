module leds (
    input  logic clk,         // board clock 25MHz 
    input  logic [15:0] data_in,
    output logic [15:0] led
);

    logic [31:0] counter2;
    logic clk2;
    logic [15:0] temp_led;

    assign temp_led = data_in[15] == 1'b1 ? data_in + 16'h8000  : (data_in + 16'h7FFF) & 16'h7FFF;

    always_ff @(posedge clk) begin
        if (counter2 == 32'd12000000) begin
            counter2 <= 0;
            clk2 <= ~clk2;
        end else begin
            counter2 <= counter2 + 1;
        end
    end

    always_ff @(posedge clk2) begin
        if (temp_led[15])      led <= 16'b1111111111111111;
        else if (temp_led[14]) led <= 16'b0111111111111111;
        else if (temp_led[13]) led <= 16'b0011111111111111;
        else if (temp_led[12]) led <= 16'b0001111111111111;
        else if (temp_led[11]) led <= 16'b0000111111111111;
        else if (temp_led[10]) led <= 16'b0000011111111111;
        else if (temp_led[9])  led <= 16'b0000001111111111;
        else if (temp_led[8])  led <= 16'b0000000111111111;
        else if (temp_led[7])  led <= 16'b0000000011111111;
        else if (temp_led[6])  led <= 16'b0000000001111111;
        else if (temp_led[5])  led <= 16'b0000000000111111;
        else if (temp_led[4])  led <= 16'b0000000000011111;
        else if (temp_led[3])  led <= 16'b0000000000001111;
        else if (temp_led[2])  led <= 16'b0000000000000111;
        else if (temp_led[1])  led <= 16'b0000000000000011;
        else if (temp_led[0])  led <= 16'b0000000000000001;
        else                  led <= 16'b0000000000000000;
    end


endmodule