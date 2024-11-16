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

// ���ź� : �Է� �޴� �����͸� ȭ�鿡 ��� 

module test_uart();
    reg clk, reset_p, transmit;
    reg [7:0] HCSR04_DATA;
    reg  Rx;  // UART �Է��� reg�� ����
    wire Tx;
    
     // Top_uart �ν��Ͻ�ȭ
    Top_uart uart_test (
        .clk(clk),
        .reset_p(reset_p),
        .Rx(Tx),
        .transmit(transmit),
        .HCSR04_DATA(HCSR04_DATA),
        .Tx_Sirial(Tx_Sirial),
        .Tx(Tx)
    );

    // Ŭ�� ����
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 10ns �ֱ��� Ŭ�� ����
    end

    // Reset ��ȣ ó��
    initial begin
        reset_p = 1; // Reset Ȱ��ȭ
        #20 reset_p = 0; // 20ns �� Reset ��Ȱ��ȭ
        Rx = Tx;
    end

    // ������ ���� �� �׽�Ʈ
    initial begin
        // �ʱ� ����
        Rx =Tx;
        HCSR04_DATA = 0;
        transmit = 0;
        
        // ������ ���� �� ���� �׽�Ʈ
        #30 HCSR04_DATA = 8'd10; // 30ns �Ŀ� ������ ����
        #10 transmit = 1; // ���� ����
        #10 transmit = 0;
        #1000 transmit = 1; // ���� ����
        #1000 transmit = 0;
        
    end
endmodule




module Top_uart(

    input clk,
    input reset_p,
    input Rx,
    input transmit,          // ���� Ʈ����
    input [7:0] HCSR04_DATA,
    output Tx_Sirial,
    output Tx);
    
    uart_test_tx tx_test(
    .clk(clk),               // FPGA Ŭ��
    .reset_p(reset_p),           // ���� ��ȣ
    .transmit(transmit),          // ���� Ʈ����
    .HCSR04_DATA(HCSR04_DATA),
    .Tx(Tx));         // UART ���� ��
    
    uart_text_rx rx_test(
    .clk(clk), .reset_p(reset_p),
    .Rx(Tx));
endmodule

// ���ź� : �Է� �޴� �����͸� ȭ�鿡 ��� 
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
    parameter BIT_PERIOD = 10417; // �� period ���ļ��� ���巹��Ʈ�� ����
    
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
                        counter_nsec_en = 0; // ī���͸� �ʱ�ȭ
                        next_state = S_IDLE;
                    end
                end
                 default: next_state <= S_IDLE;
        endcase
        end
    end
endmodule


//�۽ź� : �Է¹��� ������ ���� ���� 
module uart_test_tx(
    input clk,               // FPGA Ŭ��
    input reset_p,           // ���� ��ȣ
    input transmit,          // ���� Ʈ����
    input [7:0] HCSR04_DATA,
    output reg Tx,         // UART ���� ��
    output reg Tx_Sirial);

    parameter BIT_PERIOD = 10417; // �� period ���ļ��� ���巹��Ʈ�� ����
    
    parameter S_IDLE = 4'b0001;
    parameter S_START_BIT = 4'b0010;
    parameter S_DATA_BITS = 4'b0100;
    parameter S_STOP_BIT = 4'b1000;
    
    reg [3:0] state, next_state;
    reg [3:0] bit_index;    // ���� ���� ���� ��Ʈ�� �ε���  
    
    // ???? next_state?? state ?????? ??��??
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
            Tx = 1;         // �⺻ ���� (���̵� ���¿��� tx�� 1)
            Tx_Sirial =1;
            bit_index = 0;
            counter_nsec_en = 0;
    end 
        else begin
            case(state)
            S_IDLE: begin
                    Tx = 1;
                    Tx_Sirial = 1;
                    bit_index = 0;  // ��Ʈ �ε����� �ʱ�ȭ
                    counter_nsec_en = 0; // ī���͸� �ʱ�ȭ
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
                    counter_nsec_en = 0; // ī���͸� �ʱ�ȭ
                    next_state = S_DATA_BITS;
                end
            end
            S_DATA_BITS: begin     
                if (counter_nsec <= BIT_PERIOD) begin
                    counter_nsec_en = 1;
                    Tx = HCSR04_DATA[bit_index]; // ī���Ϳ� ������� �׻� ���� ��Ʈ����
                    Tx_Sirial = HCSR04_DATA[bit_index];
                end  
                else begin
                    counter_nsec_en = 0; // ī���͸� �ʱ�ȭ
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
                    counter_nsec_en = 0; // ī���͸� �ʱ�ȭ
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