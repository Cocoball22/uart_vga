`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/12 15:49:34
// Design Name: 
// Module Name: vga_top
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


module vga_top(
input CLK,      // FPGA???? ??????? ???
    input reset,    // ???? ???
    input [11:0] sw,
    input [7:0] position_x,
    input [7:0] position_y,
    output hsync,   // ???? ???? ???
    output vsync,   // ???? ???? ???
    output [11:0] rgb // RGB ????? ???? 12 FPGA ??
);
    
    wire video_on;         // ???????? ?????? ???
    wire [9:0] x, y;
    reg [11:0] rgb_reg;
    
    // VGA ?????? ?ν???? ????
    vga_controller vga_c(
        .CLK(CLK), 
        .reset(reset), 
        .hsync(hsync), 
        .vsync(vsync),
        .video_on(video_on), 
        .p_tick(), 
        .x(x), 
        .y(y)
    );
        
//     AsciiToPositionConverter ACT (
//    .clk(clk),
//    .reset_p(reset_p),
//    .ascii_value(position_x),    // 입력: ASCII 값 ('0'~'9', 'A'~'F')
//    .position_x(position_x)); // 출력: 해상도 범위 내 위치 값 (0~15)

   
        always @(posedge CLK or posedge reset) begin
        if (reset)
            rgb_reg <= 12'b0; // ???? ?? RGB ????????? 0???? ????
            
        else begin
            if ((x >= position_x * 40) && (x < position_x * 40 + 40) &&
                y >= (position_y * 30) && y < (position_y * 30 + 30)) begin
                rgb_reg <= sw;
            end else begin
                rgb_reg <= 0;
            end
        end
    end
    
    assign rgb = (video_on) ? rgb_reg : 12'b0; // ??? ?????? ???? ?? RGB ???? = SW, ????? ?????? ??? ????
         
endmodule

module AsciiToPositionConverter (
    input clk,
    input reset_p,
    input [7:0] ascii_value,    // 입력: ASCII 값 ('0'~'9', 'A'~'F')
    output reg [7:0] position_x // 출력: 해상도 범위 내 위치 값 (0~640)
);

     always @(posedge clk or posedge reset_p)begin
       if(reset_p) position_x = 0;
       else begin
           if(ascii_value == 48)       position_x = 0;
           else if(ascii_value == 49)  position_x = 1;
           else if(ascii_value == 50)  position_x = 2;
           else if(ascii_value == 51)  position_x = 3;
           else if(ascii_value == 52)  position_x = 4;
           else if(ascii_value == 53)  position_x = 5;
           else if(ascii_value == 54)  position_x = 6;
           else if(ascii_value == 55)  position_x = 7;
           else if(ascii_value == 56)  position_x = 8;
           else if(ascii_value == 57)  position_x = 9;
           else if(ascii_value == 65)  position_x = 10;
           else if(ascii_value == 66)  position_x = 11;
           else if(ascii_value == 67)  position_x = 12;
           else if(ascii_value == 68)  position_x = 13;
           else if(ascii_value == 69)  position_x = 14;
           else if(ascii_value == 70)  position_x = 15;
       end
   end

endmodule

module vga_controller(
    input CLK,   // from FPGA
    input reset,        // system reset
    output video_on,    // ON while pixel counts for x and y and within display area
    output hsync,       // horizontal sync
    output vsync,       // vertical sync
    output p_tick,      // the 25MHz pixel/second rate signal, pixel tick
    output [9:0] x,     // pixel count/position of pixel x, max 0-799
    output [9:0] y      // pixel count/position of pixel y, max 0-524
    );
    
    // Based on VGA standards found at vesa.org for 640x480 resolution
    // Total horizontal width of screen = 800 pixels, partitioned  into sections
    parameter HD = 640;             // horizontal display area width in pixels
    parameter HF = 48;              // horizontal front porch width in pixels
    parameter HB = 16;              // horizontal back porch width in pixels
    parameter HR = 96;              // horizontal retrace width in pixels
    parameter HMAX = HD+HF+HB+HR-1; // max value of horizontal counter = 799
    // Total vertical length of screen = 525 pixels, partitioned into sections
    parameter VD = 480;             // vertical display area length in pixels 
    parameter VF = 10;              // vertical front porch length in pixels  
    parameter VB = 33;              // vertical back porch length in pixels   
    parameter VR = 2;               // vertical retrace length in pixels  
    parameter VMAX = VD+VF+VB+VR-1; // max value of vertical counter = 524   
    
    // *** Generate 25MHz from 100MHz *********************************************************
	reg  [1:0] r_25MHz;
	wire w_25MHz;
	
	always @(posedge CLK or posedge reset)
		if(reset)
		  r_25MHz <= 0;
		else
		  r_25MHz <= r_25MHz + 1;
	
	assign w_25MHz = (r_25MHz == 0) ? 1 : 0; // assert tick 1/4 of the time
    // ****************************************************************************************
    
    // Counter Registers, two each for buffering to avoid glitches
    reg [9:0] h_count_reg, h_count_next;
    reg [9:0] v_count_reg, v_count_next;
    
    // Output Buffers
    reg v_sync_reg, h_sync_reg;
    wire v_sync_next, h_sync_next;
    
    // Register Control
    always @(posedge CLK or posedge reset)
        if(reset) begin
            v_count_reg <= 0;
            h_count_reg <= 0;
            v_sync_reg  <= 1'b0;
            h_sync_reg  <= 1'b0;
        end
        else begin
            v_count_reg <= v_count_next;
            h_count_reg <= h_count_next;
            v_sync_reg  <= v_sync_next;
            h_sync_reg  <= h_sync_next;
        end
         
    //Logic for horizontal counter
    always @(posedge w_25MHz or posedge reset)      // pixel tick
        if(reset)
            h_count_next = 0;
        else
            if(h_count_reg == HMAX)                 // end of horizontal scan
                h_count_next = 0;
            else
                h_count_next = h_count_reg + 1;         
  
    // Logic for vertical counter
    always @(posedge w_25MHz or posedge reset)
        if(reset)
            v_count_next = 0;
        else
            if(h_count_reg == HMAX)                 // end of horizontal scan
                if((v_count_reg == VMAX))           // end of vertical scan
                    v_count_next = 0;
                else
                    v_count_next = v_count_reg + 1;
        
    // h_sync_next asserted within the horizontal retrace area
    assign h_sync_next = (h_count_reg >= (HD+HB) && h_count_reg <= (HD+HB+HR-1));
    
    // v_sync_next asserted within the vertical retrace area
    assign v_sync_next = (v_count_reg >= (VD+VB) && v_count_reg <= (VD+VB+VR-1));
    
    // Video ON/OFF - only ON while pixel counts are within the display area
    assign video_on = (h_count_reg < HD) && (v_count_reg < VD); // 0-639 and 0-479 respectively
            
    // Outputs
    assign hsync  = h_sync_reg;
    assign vsync  = v_sync_reg;
    assign x      = h_count_reg;
    assign y      = v_count_reg;
    assign p_tick = w_25MHz;
            
endmodule



