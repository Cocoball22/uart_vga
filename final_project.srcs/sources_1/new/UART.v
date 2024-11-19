`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/15 11:04:55
// Design Name: 
// Module Name: UART
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

module UART_TOP(
    
    input clk,
    input reset_p,
    input Rx,
    input hc_sr04_echo_X,
    input hc_sr04_echo_Y,
    output hc_sr04_trig_X,
    output hc_sr04_trig_Y,
    output [7:0] Rx_data,
    output [3:0] com,
    output [7:0] seg_7,
    output Tx_x , Tx_y);
    
    UART_RX rx(
    .clk(clk),               // FPGA 클럭
    .reset_p(reset_p),           // 리셋 신호
    .Rx(Rx),
    .Rx_data(Rx_data));         // UART 전송 핀
    
    wire [7:0] distance_X_cm, distance_Y_cm ;
    
    HC_SR04_double_top HC_SR04(
    .clk(clk), .reset_p(reset_p), 
    .hc_sr04_echo_X(hc_sr04_echo_X),
    .hc_sr04_echo_Y(hc_sr04_echo_Y),
    .hc_sr04_trig_X(hc_sr04_trig_X),
    .hc_sr04_trig_Y(hc_sr04_trig_Y),
    .distance_X_cm(distance_X_cm),
    .distance_Y_cm(distance_Y_cm),
    .com(com),
    .seg_7(seg_7));
    
    UART_TX tx_x(
    .clk(clk), 
    .reset_p(reset_p),
    .Hcsr04_data(distance_X_cm),
    .Tx(Tx_x));

     UART_TX tx_y(
    .clk(clk), 
    .reset_p(reset_p),
    .Hcsr04_data(distance_Y_cm),
    .Tx(Tx_y));
endmodule


// 수신부 : 입력 받는 데이터를 화면에 출력 
module UART_RX(
    input clk, reset_p,
    input Rx,
    output reg [7:0] Rx_data,
    output [4:0] led_debug);

    parameter S_IDLE = 3'b001;
    parameter S_DATA_BITS = 3'b010;
    parameter S_STOP_BIT = 3'b100;
    parameter BIT_PERIOD = 10417; // 한 period 주파수를 보드레이트로 나눔
    
    // state 
    reg [3:0] state, next_state;
    
    assign led_debug = state;
    
    always @(posedge clk or posedge reset_p) begin
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
            state = S_IDLE;
            counter_nsec_en = 0;
            bit_index = 0;
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
                       if(Rx == 1'd1)begin
                            next_state = S_IDLE;
                       end
                    end 
                    else begin
                        counter_nsec_en = 0; // 카운터를 초기화
                        next_state = S_IDLE;
                    end
                end
                 default: next_state <= S_IDLE;
        endcase
        end
    end
endmodule

//송신부 : 입력받은 초음파 값을 전송 
module UART_TX(
    input clk,               // FPGA 클럭
    input reset_p,           // 리셋 신호
    input [7:0]Hcsr04_data,
    output reg Tx);         // UART 전송 핀
    

    parameter BIT_PERIOD = 10417; // 한 period 주파수를 보드레이트로 나눔
    
    parameter S_IDLE = 4'b0001;
    parameter S_START_BIT = 4'b0010;
    parameter S_DATA_BITS = 4'b0100;
    parameter S_STOP_BIT = 4'b1000;
    
    reg [3:0] state, next_state;
    reg [3:0] bit_index;    // 현재 전송 중인 비트의 인덱스  
    
    // ???? next_state?? state ?????? ??°??
    always @(negedge clk or posedge reset_p) begin
        if(reset_p) state = S_IDLE;
        else state = next_state;
    end
    
     // making 10nsec counter.
    reg [31:0] counter_nsec;
    reg counter_nsec_en;
    
   clock_div_100 usec_clk(.clk(clk), .reset_p(reset_p), .clk_div_100(clk_usec));
   clock_div_1000 msec_clk(.clk(clk), .reset_p(reset_p),
        .clk_source(clk_usec), .clk_div_1000(clk_msec));
    clock_div_1000 sec_clk(.clk(clk), .reset_p(reset_p), 
        .clk_source(clk_msec), .clk_div_1000_nedge(clk_sec));
    
    always @(negedge clk or posedge reset_p) begin
        if(reset_p) begin counter_nsec = 0;
        end else if(counter_nsec_en) counter_nsec = counter_nsec + 1;
        else if(!counter_nsec_en) counter_nsec = 0;
    end

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            next_state = S_IDLE;
            bit_index = 0;
            counter_nsec_en = 0;
            Tx = 1;
    end 
        else begin
            case(state)
            S_IDLE: begin
                    bit_index = 0;  // 비트 인덱스를 초기화
                    counter_nsec_en = 0; // 카운터를 초기화
                    Tx = 1;
                if(clk_sec)begin
                    next_state = S_START_BIT;
                end
            end
            S_START_BIT: begin
                if (counter_nsec <= BIT_PERIOD) begin
                   counter_nsec_en = 1;
                   Tx = 0;
                end 
                else begin
                    counter_nsec_en = 0; // 카운터를 초기화
                    next_state = S_DATA_BITS;
                end
            end
            S_DATA_BITS: begin     
                if (counter_nsec <= BIT_PERIOD) begin
                    counter_nsec_en = 1;
                    Tx = Hcsr04_data[bit_index];
                end  
                else begin
                    counter_nsec_en = 0; // 카운터를 초기화
                    bit_index = bit_index + 1;
                    if(bit_index == 8)begin
                        next_state = S_STOP_BIT;
                        bit_index = 0;
                    end
                end  
            end
            S_STOP_BIT: begin
                if (counter_nsec <= BIT_PERIOD) begin
                    counter_nsec_en = 1;
                    Tx = 1;
                end              
                else begin
                    counter_nsec_en = 0; // 카운터를 초기화
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

// make 1ms
module clock_div_100(
    input clk, reset_p,
    output clk_div_100,
    output clk_div_100_nedge);
    
    reg [6:0] cnt_sysclk;
    
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)cnt_sysclk = 0;
        else begin
            if(cnt_sysclk >= 99) cnt_sysclk = 0;
            else cnt_sysclk = cnt_sysclk + 1;
        end
    end
    
    assign clk_div_100 = (cnt_sysclk < 50) ? 0 : 1;
    
    edge_detector_p ed(
        .clk(clk), .reset_p(reset_p), .cp(clk_div_100),
        .n_edge(clk_div_100_nedge));
endmodule

module clock_div_1000(
    input clk, reset_p,
    input clk_source,
    output clk_div_1000,
    output clk_div_1000_nedge);
    
    reg [9:0] cnt_clksource;
    
    wire clk_source_nedge;
    edge_detector_p ed_source(
        .clk(clk), .reset_p(reset_p), .cp(clk_source),
        .n_edge(clk_source_nedge));
    
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)cnt_clksource = 0;
        else if(clk_source_nedge)begin
            if(cnt_clksource >= 999) cnt_clksource = 0;
            else cnt_clksource = cnt_clksource + 1;
        end
    end
    
    assign clk_div_1000 = (cnt_clksource < 500) ? 0 : 1;
    
    edge_detector_p ed(
        .clk(clk), .reset_p(reset_p), .cp(clk_div_1000),
        .n_edge(clk_div_1000_nedge));
endmodule