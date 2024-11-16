`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/11 09:48:00
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

// 수신부 : 입력 받는 데이터를 화면에 출력 

module test_uart();
    reg clk, reset_p, transmit;
    reg [7:0] HCSR04_DATA;
    reg  Rx;  // UART 입력은 reg로 선언
    wire Tx;
    
     // Top_uart 인스턴스화
    Top_uart uart_test (
        .clk(clk),
        .reset_p(reset_p),
        .Rx(Tx),
        .transmit(transmit),
        .HCSR04_DATA(HCSR04_DATA),
        .Tx_Sirial(Tx_Sirial),
        .Tx(Tx)
    );

    // 클럭 생성
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 10ns 주기의 클럭 생성
    end

    // Reset 신호 처리
    initial begin
        reset_p = 1; // Reset 활성화
        #20 reset_p = 0; // 20ns 후 Reset 비활성화
        Rx = Tx;
    end

    // 데이터 설정 및 테스트
    initial begin
        // 초기 설정
        Rx =Tx;
        HCSR04_DATA = 0;
        transmit = 0;
        
        // 데이터 설정 후 전송 테스트
        #30 HCSR04_DATA = 8'd10; // 30ns 후에 데이터 설정
        #10 transmit = 1; // 전송 시작
        #10 transmit = 0;
        #1000 transmit = 1; // 전송 시작
        #1000 transmit = 0;
        
    end
endmodule




module Top_uart(

    input clk,
    input reset_p,
    input Rx,
    input transmit,          // 전송 트리거
    input [7:0] HCSR04_DATA,
    output Tx_Sirial,
    output Tx);
    
    uart_test_tx tx_test(
    .clk(clk),               // FPGA 클럭
    .reset_p(reset_p),           // 리셋 신호
    .transmit(transmit),          // 전송 트리거
    .HCSR04_DATA(HCSR04_DATA),
    .Tx(Tx));         // UART 전송 핀
    
    uart_text_rx rx_test(
    .clk(clk), .reset_p(reset_p),
    .Rx(Tx));
endmodule

// 수신부 : 입력 받는 데이터를 화면에 출력 
module uart_text_rx(
    input clk, reset_p,
    input Rx,
    output reg Tx_Sirial,
    output reg [7:0] Rx_data,
    output [15:0] led_debug
);

    parameter S_IDLE = 3'b001;
    parameter S_DATA_BITS = 3'b010;
    parameter S_STOP_BIT = 3'b100;
    parameter BIT_PERIOD = 10417; // 한 period 주파수를 보드레이트로 나눔
    
    // state 
    reg [3:0] state, next_state;
    
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) state = S_IDLE;
        else state = next_state;
    end

    reg [3:0] bit_index;

    
    assign led_debug[3:0] = state;
    assign led_debug[15:4] = Rx_data;
    
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
            Tx_Sirial = 1;
        end
        else begin
            case(state)
                S_IDLE: begin
                    Tx_Sirial = Rx;
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
                        Tx_Sirial = Rx;
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
                        Tx_Sirial = Rx;
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
module uart_test_tx(
    input clk,               // FPGA 클럭
    input reset_p,           // 리셋 신호
    input transmit,          // 전송 트리거
    input [7:0] HCSR04_DATA,
    output reg Tx,         // UART 전송 핀
    output reg Tx_Sirial);

    parameter BIT_PERIOD = 10417; // 한 period 주파수를 보드레이트로 나눔
    
    parameter S_IDLE = 4'b0001;
    parameter S_START_BIT = 4'b0010;
    parameter S_DATA_BITS = 4'b0100;
    parameter S_STOP_BIT = 4'b1000;
    
    reg [3:0] state, next_state;
    reg [3:0] bit_index;    // 현재 전송 중인 비트의 인덱스  
    
    // ???? next_state?? state ?????? ??°??
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) state = S_IDLE;
        else state = next_state;
    end
    
     // making 10nsec counter.
    reg [31:0] counter_nsec;
    reg counter_nsec_en;
    
    always @(negedge clk or posedge reset_p) begin
        if(reset_p) begin counter_nsec = 0;
        end else if(counter_nsec_en) counter_nsec = counter_nsec + 1;
        else if(!counter_nsec_en) counter_nsec = 0;
    end

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            next_state = S_IDLE;
            Tx = 1;         // 기본 상태 (아이들 상태에서 tx는 1)
            Tx_Sirial =1;
            bit_index = 0;
            counter_nsec_en = 0;
    end 
        else begin
            case(state)
            S_IDLE: begin
                    Tx = 1;
                    Tx_Sirial = 1;
                    bit_index = 0;  // 비트 인덱스를 초기화
                    counter_nsec_en = 0; // 카운터를 초기화
                if(!transmit)begin
                    next_state = S_START_BIT;
                end
            end
            S_START_BIT: begin
                if (counter_nsec <= BIT_PERIOD) begin
                   counter_nsec_en = 1;
                   Tx = 0;
                   Tx_Sirial = 0;
                end 
                else begin
                    counter_nsec_en = 0; // 카운터를 초기화
                    next_state = S_DATA_BITS;
                end
            end
            S_DATA_BITS: begin     
                if (counter_nsec <= BIT_PERIOD) begin
                    counter_nsec_en = 1;
                    Tx = HCSR04_DATA[bit_index]; // 카운터와 관계없이 항상 현재 비트유지
                    Tx_Sirial = HCSR04_DATA[bit_index];
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
                Tx = 1;
                Tx_Sirial = 1;
                if (counter_nsec <= BIT_PERIOD) begin
                    counter_nsec_en = 1;
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