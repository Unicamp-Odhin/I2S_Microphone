module leds (
    input  logic clk,         // board clock 25MHz 
    input  logic [15:0] data_in,
    output logic [15:0] led
);

    logic [31:0] counter2;
    logic clk2;
    
    always_ff @(posedge clk) begin
        if (counter2 == 32'd3000000) begin
            counter2 <= 0;
            clk2 <= ~clk2;
        end else begin
            counter2 <= counter2 + 1;
        end
    end

    always_ff @(posedge clk2) begin
        int intensity;
        if (data_in[15] == 1)  // Número negativo em complemento de dois
            intensity = 16 + (data_in >> 12); // Ajusta escala para 0-16
        else 
            intensity = data_in >> 12; // Ajusta escala para 0-16
        
        led = (16'hFFFF >> (16 - intensity)); // Ativa LEDs proporcionais
    end

endmodule