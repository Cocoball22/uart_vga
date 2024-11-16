`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/12 09:28:26
// Design Name: 
// Module Name: Top_module_test
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


module Top_module_test(
    input clk,
    input reset_p,
    input hc_sr04_echo_X,
    input hc_sr04_echo_Y,
    input [11:0] sw,
    output hc_sr04_trig_X,
    output hc_sr04_trig_Y,

    output [3:0] com,
    output [7:0] seg_7,
    output Tx,         // UART 전송 핀
    output Tx_Sirial,
    output hsync,   
    output vsync,   
    output [11:0] rgb);
    
    wire [7:0] distance_X_cm;
    wire [7:0] distance_Y_cm;
    wire transmit_X, transmit_Y;
    
    HC_SR04_double_top TEST_SR04(
    .clk(clk), .reset_p(reset_p), 
    .hc_sr04_echo_X(hc_sr04_echo_X),
    .hc_sr04_echo_Y(hc_sr04_echo_Y),
    .hc_sr04_trig_X(hc_sr04_trig_X),
    .hc_sr04_trig_Y(hc_sr04_trig_Y),
    .distance_X_cm(distance_X_cm),
    .distance_Y_cm(distance_Y_cm),
    .transmit_X(transmit_X),
    .transmit_Y(transmit_Y),
    .com(com),
    .seg_7(seg_7));
    
    wire [7:0] distance_X_cm_bin_ascii;
    wire [7:0] distance_Y_cm_bin_ascii;
    wire [7:0] mux_data_out;
    
    BinaryToASCII BIN_ASCII_X (
    .clk(clk),
    .reset_p(reset_p),
    .binary_value(distance_X_cm),   // 4비트 입력 값 (0 ~ 15)
    .ascii_value(distance_X_cm_bin_ascii)); // 변환된 8비트 ASCII 값
    
    BinaryToASCII BIN_ASCII_Y (
    .clk(clk),
    .reset_p(reset_p),
    .binary_value(distance_Y_cm),   // 4비트 입력 값 (0 ~ 15)
    .ascii_value(distance_Y_cm_bin_ascii)); // 변환된 8비트 ASCII 값
    
   MUX_2_to_1 (
    .clk(clk),
    .reset_p(reset_p),
    .distance_X_cm_bin_ascii(distance_X_cm_bin_ascii), // 첫 번째 입력
    .distance_Y_cm_bin_ascii(distance_Y_cm_bin_ascii), // 두 번째 입력
    .select({transmit_Y,transmit_X}),                        // 선택 신호 (0 또는 1)
    .data_out(mux_data_out)                 // 출력 데이터
);
    
    uart_test_tx TEST_TX_X(
    .clk(clk),             // FPGA 클럭
    .reset_p(reset_p),           // 리셋 신호
    .transmit(transmit_X), // 전송 트리거
    .HCSR04_DATA(mux_data_out), 
    .Tx(Tx),         // UART 전송 핀
    .Tx_Sirial(Tx_Sirial));
    
//    module uart_text_rx(
//    input clk, reset_p,
//    input Rx,
//    output Rx_data,
//    output reg Tx_Sirial,
//    output [15:0] led_debug
//);
    
    vga_top TEST_RGB(
    .CLK(clk),      // FPGA???? ??????? ???
    .reset(reset),    // ???? ???
    .sw(sw),
    .position_x(distance_X_cm),
    .position_y(distance_Y_cm),
    .hsync(hsync),   // ???? ???? ???
    .vsync(vsync),   // ???? ???? ???
    .rgb(rgb)); // RGB ????? ???? 12 FPGA ??

    
endmodule
