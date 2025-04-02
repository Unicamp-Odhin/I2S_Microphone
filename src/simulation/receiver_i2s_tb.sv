`timescale 1ns / 1ps

module receiver_i2s_tb;
    parameter int DATA_SIZE = 16;

    logic clk;
    logic rst_n;
    logic i2s_sd;
    logic i2s_ws;
    logic [DATA_SIZE-1:0] audio_data;
    logic ready;

    receiver_i2s #(.DATA_SIZE(DATA_SIZE)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i2s_sd(i2s_sd),
        .i2s_ws(i2s_ws),
        .audio_data(audio_data),
        .ready(ready)
    );

    always #5 clk = ~clk;
    logic [15:0] info;

    // Teste
    initial begin
        $dumpfile("simulation/receiver.vcd");
        $dumpvars(0, receiver_i2s_tb);  

        rst_n = 1;
        
        for (int j = 0; j < 10; j++) begin
            for (int i = 0; i < DATA_SIZE; i++) begin
                #10 i2s_sd <= $random;
            end
        end
        #50;
        $finish;
    end

    // Monitoramento
    initial begin
        $monitor("Time=%0t, i2s_sd=%b, audio_data=%h, ready=%b", 
                 $time, i2s_sd, audio_data, ready);
    end
endmodule
