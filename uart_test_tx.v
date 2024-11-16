`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/10 10:25:44
// Design Name: 
// Module Name: uart_test_tx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_test_tx(
    input clk,             // FPGA Ŭ��
    input reset_p,           // ���� ��ȣ
    input transmit, // ���� Ʈ����
    input [7:0] sw,
    output reg Tx,         // UART ���� ��
    output [15:0] led_debug);

    parameter CLOCK_FREQ = 100000000; // 100 MHz
    parameter BAUD_RATE = 9600;
    parameter BIT_PERIOD = CLOCK_FREQ / BAUD_RATE; // �� period ���ļ��� ���巹��Ʈ�� ����
    
    parameter S_IDLE = 4'b0001;
    parameter S_START_BIT = 4'b0010;
    parameter S_DATA_BITS = 4'b0100;
    parameter S_STOP_BIT = 4'b1000;
    
    reg [3:0] state, next_state;
    reg [3:0] bit_index;    // ���� ���� ���� ��Ʈ�� �ε���
    reg [9:0] shiftright_register; // 10 bits that will be serially transmitted through UART to the basys3
     
    // For Test
    assign led_debug[3:0] = state;
    //assign led_debug[4] = tx;
    // ����׸� ���� ��ȣ ���
   // assign led_debug[5] = counter_usec_en;  // ī���� ���� ���� Ȯ��
    assign led_debug[15:6] = sw;
    
    // ???? next_state?? state ?????? ??��??
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) state = S_IDLE;
        else state = next_state;
    end
    
    // get 10us negative one cycle pulse
    wire clk_usec;
    clock_div_100   usec_clk( .clk(clk), .reset_p(reset_p), .clk_div_100_nedge(clk_usec));     // 1us
    
     // making usec counter.
    reg [31:0] counter_usec;
    reg counter_usec_en;
    
    always @(negedge clk or posedge reset_p) begin
        if(reset_p) begin counter_usec = 0;
        end else if(clk_usec && counter_usec_en) counter_usec = counter_usec + 1;
        else if(!counter_usec_en) counter_usec = 0;
    end

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            next_state = S_IDLE;
            Tx = 1;         // �⺻ ���� (���̵� ���¿��� tx�� 1)
            bit_index = 0;
            counter_usec_en = 0;
            shiftright_register = {1'b1, sw, 1'b0};
    end 
        else begin
            case(state)
            S_IDLE: begin
                    Tx = 1;
                    bit_index = 0;  // ��Ʈ �ε����� �ʱ�ȭ
                    counter_usec_en = 0; // ī���͸� �ʱ�ȭ
                    shiftright_register = {1'b1, sw[7:0], 1'b0};
                if (transmit) begin
                    next_state = S_START_BIT;
                end else begin
                    next_state = S_IDLE;
                end 
            end
            S_START_BIT: begin
                if (counter_usec < BIT_PERIOD-1) begin
                   counter_usec_en = 1;
                    Tx = shiftright_register[0]; // LSB���� ����
                end 
                else begin
                    counter_usec_en = 0; // ī���͸� �ʱ�ȭ
                    next_state = S_DATA_BITS;
                end
            end
            S_DATA_BITS: begin     
                if (counter_usec < BIT_PERIOD-1) begin
                    counter_usec_en = 1;
                    Tx = shiftright_register[0]; // LSB���� ����
                end  
                else begin
                    counter_usec_en = 0; // ī���͸� �ʱ�ȭ
                    shiftright_register = {1'b1, shiftright_register[9:1]}; // ���������� ����Ʈ
                    if(bit_index == 7)begin
                        next_state = S_STOP_BIT;
                        bit_index = 0;
                    end 
                    else begin
                        bit_index = bit_index + 1;
                        next_state = S_DATA_BITS;
                    end
                end  
            end
            S_STOP_BIT: begin
                if (counter_usec < BIT_PERIOD-1) begin
                    counter_usec_en = 1;
                    Tx = 1;
                end              
                else begin
                    counter_usec_en = 0; // ī���͸� �ʱ�ȭ
                    next_state = S_IDLE;
                end
            end
            default: begin
                    next_state = S_IDLE;
            end
            endcase
        end  
    end
   
endmodule



module uart_test_tx_tb;

    reg clk;
    reg reset_p;
    reg btn_set;
    wire tx;
    wire [5:0] led_debug;

    // Ŭ�� ���� (100MHz)
    always #5 clk = ~clk;

    // DUT (Device Under Test) �ν��Ͻ�ȭ
    uart_test_tx uut (
        .clk(clk),
        .reset_p(reset_p),
        .btn_set(btn_set),
        .tx(tx),
        .led_debug(led_debug)
    );

    initial begin
        // �ʱ� ��ȣ ����
        clk = 0;
        reset_p = 1;
        btn_set = 0;

        // ���� ���� �� �ùķ��̼� ����
        #20 reset_p = 0;
        #10 btn_set = 1;
        #20 btn_set = 0;

    end
endmodule


