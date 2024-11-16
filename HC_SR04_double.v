`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/12 10:51:47
// Design Name: 
// Module Name: HC_SR04_double
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

module HC_SR04_double_top (
    input clk, reset_p, 
    input hc_sr04_echo_X,
    input hc_sr04_echo_Y,
    output hc_sr04_trig_X,
    output hc_sr04_trig_Y,
    output [7:0] distance_X_cm,
    output [7:0] distance_Y_cm,
    output transmit_X,
    output transmit_Y,
    output [3:0] com,
    output [7:0] seg_7);
    
    
    HC_SR04_uart_ctnr HC_SR04_cntr_0(.clk(clk), .reset_p(reset_p),
     .hc_sr04_echo(hc_sr04_echo_X), .hc_sr04_trig(hc_sr04_trig_X),
      .distance(distance_X_cm),.transmit(transmit_X)); // ���� ��ȣ ����

    HC_SR04_uart_ctnr HC_SR04_cntr_1(.clk(clk), .reset_p(reset_p),
     .hc_sr04_echo(hc_sr04_echo_Y), .hc_sr04_trig(hc_sr04_trig_Y),
      .distance(distance_Y_cm),.transmit(transmit_Y)); // ���� ��ȣ ����
    
     wire [7:0] distance_X_cm_bcd;
     wire [7:0] distance_Y_cm_bcd;

    bin_to_dec bcd_1(.bin(distance_X_cm[7:0]),  .bcd(distance_X_cm_bcd));
    bin_to_dec bcd_2(.bin(distance_Y_cm[7:0]),  .bcd(distance_Y_cm_bcd));

    // ���յ� ���� �����ϴ� �κ�
    wire [15:0] combined_value;
    assign combined_value = {distance_X_cm_bcd, distance_Y_cm_bcd}; // ���յ� 16��Ʈ ��

    // FND ���� ���
    fnd_cntr fnd (
        .clk(clk), 
        .reset_p(reset_p),
        .value(combined_value), // ���� 8��Ʈ ���
        .com(com), 
        .seg_7(seg_7)
    );

endmodule

module HC_SR04_uart_ctnr(
    input clk, reset_p, 
    input hc_sr04_echo,
    output reg hc_sr04_trig,
    output reg [21:0] distance,
    output reg transmit);
    
    // Define state 
    parameter S_IDLE                 = 4'b0001;
    parameter S_10US_TTL             = 4'b0010;
    parameter S_WAIT_PEDGE           = 4'b0100;
    parameter S_CALC_DIST            = 4'b1000;
    
    // Define state, next_state value.
    reg [3:0] state, next_state;
    
    // ���� next_state�� state ������ �ִ°�?
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) state = S_IDLE;
        else state = next_state;
    end
    
    // get 10us negative one cycle pulse
    wire clk_usec;
    clock_div_100   usec_clk( .clk(clk), .reset_p(reset_p), .clk_div_100_nedge(clk_usec));     // 1us
    
    reg cnt_e;
    wire [11:0] cm;
    sr04_div_58 div58(.clk(clk), .reset_p(reset_p), 
        .clk_usec(clk_usec), .cnt_e(cnt_e), .cm(cm));
    
    // making usec counter.
    reg [21:0] counter_usec;
    reg counter_usec_en;
    
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin counter_usec = 0;
        end else if(clk_usec && counter_usec_en) counter_usec = counter_usec + 1;
        else if(!counter_usec_en) counter_usec = 0;
    end
    
    
    // hc_sr04_data�� Negative edge, Positive edge ���?.
    wire hc_sr04_echo_n_edge, hc_sr04_echo_p_edge;
    edge_detector_p edge_detector_0 (.clk(clk), .reset_p(reset_p), .cp(hc_sr04_echo), .n_edge(hc_sr04_echo_n_edge), .p_edge(hc_sr04_echo_p_edge));
    
    // ���� õ�̵��� ���� case�� ����
    // �� ���¿� ���� ���� ����
    
    reg [21:0] echo_time;
    always @(negedge clk or posedge reset_p) begin
        if(reset_p) begin
            next_state = S_IDLE;
            counter_usec_en = 0; 
            echo_time = 0;
            cnt_e = 0;
            transmit = 0; 
        end else begin
            case(state)
                S_IDLE : begin        
                    if(counter_usec < 22'd3_000_000) begin
                        counter_usec_en = 1;  
                        hc_sr04_trig = 0;
                        transmit = 0;
                    end
                    else begin
                        counter_usec_en = 0;
                        next_state = S_10US_TTL;
                    end
                end
                S_10US_TTL : begin
                    if(counter_usec < 22'd10) begin
                        counter_usec_en = 1;
                        hc_sr04_trig = 1;
                    end
                    else begin
                        hc_sr04_trig = 0;
                        counter_usec_en = 0;
                        next_state = S_WAIT_PEDGE;
                    end
                end
                S_WAIT_PEDGE :  
                    if(hc_sr04_echo_p_edge) begin
                         next_state = S_CALC_DIST;    
                         cnt_e = 1;
                    end     
                S_CALC_DIST : begin          
                     if(hc_sr04_echo_n_edge) begin
                                distance = cm;
                                cnt_e = 0;
                                transmit = 1;
                                next_state = S_IDLE;
                      end
                      else next_state = S_CALC_DIST;
                end
                default: begin
                    next_state = S_IDLE;
                end
            endcase
        end
    end
    
endmodule

module BinaryToASCII (
    input clk,
    input reset_p,
    input [7:0] binary_value,   // 4��Ʈ �Է� �� (0 ~ 15)
    output reg [7:0] ascii_value // ��ȯ�� 8��Ʈ ASCII ��
);

    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin
            ascii_value  = 0;
        end
        else begin
            if (binary_value <= 7'd9) begin
            // '0'�� ASCII ���� 48, �� 8'b00110000
            ascii_value = 8'd48 + binary_value;
        end else begin
            // 'A'�� ASCII ���� 65, �� 8'b01000001
            ascii_value = 8'd65 + (binary_value - 7'd10);
        end
        end
    end
endmodule

module MUX_2_to_1 (
    input clk,
    input reset_p,
    input [7:0] distance_X_cm_bin_ascii, // ù ��° �Է�
    input [7:0] distance_Y_cm_bin_ascii, // �� ��° �Է�
    input [1:0] select,                        // ���� ��ȣ (0 �Ǵ� 1)
    output reg [7:0] data_out                 // ��� ������
);

    always @(negedge clk or posedge reset_p) begin
        if(reset_p) begin
            data_out = 0;
        end else begin
        if (select[0] == 1) begin
            data_out = distance_Y_cm_bin_ascii; // select�� 1�� �� �� ��° �Է� ����
        end else if (select[1] == 1) begin
            data_out = distance_X_cm_bin_ascii; // select�� 0�� �� ù ��° �Է� ����
        end
    end
 end   

endmodule



