`timescale 1ns / 1ps

module main_tb;
    logic clk = 0;
    logic M_DATA = 0;
    logic M_CLK;
    logic M_LRCLK; // Corrected signal name
    logic cs = 1;
    logic MOSI = 0; // Corrected signal name
    logic sck = 0;
    logic miso;
    logic LED0, LED1, LED2, LED3, LED4, LED5, LED6, LED7;
    logic [15:0] pcm_out;
    logic pcm_ready;
    logic rst_n ;
    logic [15:0] data_in;

    // Instância do módulo principal
    main uut (
        .clk(clk),
        .M_DATA(M_DATA),
        .M_CLK(M_CLK),
        .M_LRSEL(M_LRSEL),
        .cs(cs),
        .mosi(mosi),
        .sck(sck),
        .miso(miso),
        .LED0(LED0), .LED1(LED1), .LED2(LED2), .LED3(LED3),
        .LED4(LED4), .LED5(LED5), .LED6(LED6), .LED7(LED7),
        .pcm_out(pcm_out),
        .pcm_ready(pcm_ready),
        .rst_n(rst_n)
        );

    // Geração do clock
    always #40 clk = ~clk; // 25MHz -> período de 40ns

    always #2500 sck = ~sck; 

    logic [7:0] memory [0 : 10]; // Dados de teste
    initial begin
        memory[0] = 8'h00;
        memory[1] = 8'h01;
        memory[2] = 8'h02;
        memory[3] = 8'h03;
        memory[4] = 8'h04;
        memory[5] = 8'h05;
        memory[6] = 8'h06;
        memory[7] = 8'h07;
        memory[8] = 8'h08;
        memory[9] = 8'h09;
        memory[10] = 8'h0A; // Adicione mais dados conforme necessário
    end

    initial begin

        $dumpfile("simulation/main.vcd");
        $dumpvars(0, main_tb);

        $monitor("clk=%b | M_CLK=%b | M_DATA=%b | cs=%b | pcm_out=%b | pcm_ready=%b | rst_n=%b", clk, M_CLK, M_DATA, cs, pcm_out, pcm_ready, rst_n);

        M_DATA = 0;
        cs = 0;
        rst_n = 1; 


        foreach (memory[i]) begin
            data_in = memory[i];
            $display("Sending data_in: %h", data_in); // Exibe o valor de data_in
            for (int j = 7; j >= 0; j--) begin
            M_DATA = memory[i][j];
            #320;
            end
        end

        #20;
        cs = 1;
        #20;
        $stop;
    end
endmodule