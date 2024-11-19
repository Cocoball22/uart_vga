`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/19 14:28:33
// Design Name: 
// Module Name: UART_RX
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


module UART_RX(
    input clk, reset_p,
    input Rx,
    output reg [7:0] Rx_data,
    output reg [4:0] led_debug);

    parameter S_IDLE = 3'b001;
    parameter S_DATA_BITS = 3'b010;
    parameter S_STOP_BIT = 3'b100;
    parameter BIT_PERIOD = 10417; // �� period ���ļ��� ���巹��Ʈ�� ����
    
    // state 
    reg [3:0] state, next_state;
    
//    assign led_debug = state;
    
    always @(negedge clk or posedge reset_p) begin
        if(reset_p) state = S_IDLE;
        else state = next_state;
    end

    reg [3:0] bit_index;
    
    // making 10nsec counter.
    reg [31:0] counter_nsec;
    reg counter_nsec_en;
    
    always @(negedge clk or posedge reset_p) begin
        if(reset_p) begin counter_nsec = 0;
        end else if(counter_nsec_en) counter_nsec = counter_nsec + 1;
        else if(!counter_nsec_en) counter_nsec = 0;
    end
    
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            next_state = S_IDLE;
            counter_nsec_en = 0;
            bit_index = 0;
            led_debug = 0;
            Rx_data = 0;
        end
        else begin
            case(state)
                S_IDLE: begin
                    bit_index = 0;
                    counter_nsec_en = 0;
                    if(counter_nsec <= BIT_PERIOD)begin
                        counter_nsec_en = 1;
                    end else begin
                        counter_nsec_en = 0;
                        if(Rx == 1'd0)begin
                        next_state = S_DATA_BITS;
                        end else if(Rx == 1'd1) begin
                            next_state = S_IDLE;
                        end
                    end     
                end
                S_DATA_BITS: begin
                    if(counter_nsec <= BIT_PERIOD)begin
                        counter_nsec_en = 1;
                        Rx_data[bit_index] = Rx;
                        led_debug = 1;
                end else begin
                        counter_nsec_en = 0;
                        bit_index = bit_index +1;
                        if(bit_index == 8) begin
                            bit_index = 0;
                            next_state = S_STOP_BIT;
                        end
                    end
                 end
                 S_STOP_BIT: begin
                   if (counter_nsec <= BIT_PERIOD) begin
                       counter_nsec_en = 1;
                    end 
                    else begin
                        counter_nsec_en = 0; // ī���͸� �ʱ�ȭ
                        next_state = S_IDLE;
                    end
                end
                 default: next_state <= S_IDLE;
        endcase
        end
    end
endmodule