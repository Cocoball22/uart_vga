`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/15 19:00:25
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


module UART_TOP(
    
    input clk,
    input reset_p,
    input Rx_x,Rx_y,
    input  [15:0] value,
    output [3:0] com,
    output [7:0] seg_7,
    output hsync,   // ???? ???? ???
    output vsync,   // ???? ???? ???
    output [11:0] rgb);
    
    wire [7:0] Rx_data_position_x , Rx_data_position_y ;
    wire [15:0] Rx_data;
    
    UART_RX rx_x(
    .clk(clk),               // FPGA Ŭ��
    .reset_p(reset_p),           // ���� ��ȣ
    .Rx(Rx_x),
    .Rx_data(Rx_data_position_x));         // UART ���� ��
    
    UART_RX rx_y(
    .clk(clk),               // FPGA Ŭ��
    .reset_p(reset_p),           // ���� ��ȣ
    .Rx(Rx_y),
    .Rx_data(Rx_data_position_y));         // UART ���� ��
  
  
    vga_top vga(
    .clk(clk),      // FPGA???? ??????? ???
    .reset_p(reset_p),    // ???? ???
    .position_x(Rx_data_position_x),
    .position_y(Rx_data_position_y),
    .hsync(hsync),   // ???? ???? ???
    .vsync(vsync),   // ???? ???? ???
    .rgb(rgb)); // RGB ????? ???? 12 FPGA ??
    
    assign Rx_data = {Rx_data_position_y, Rx_data_position_x};
    fnd_cntr fnd(.clk(clk), .reset_p(reset_p), .value(Rx_data), .com(com), .seg_7(seg_7));


endmodule

module UART_RX(
    input clk, reset_p,
    input Rx,
    output reg [7:0] Rx_data,
    output [4:0] led_debug);

    parameter S_IDLE = 3'b001;
    parameter S_DATA_BITS = 3'b010;
    parameter S_STOP_BIT = 3'b100;
    parameter BIT_PERIOD = 10417; // �� period ���ļ��� ���巹��Ʈ�� ����
    
    // state 
    reg [3:0] state, next_state;
    
    assign led_debug = state;
    
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

module vga_top(
    input clk,      // FPGA???? ??????? ???
    input reset_p,    // ???? ???
    input [7:0] position_x,
    input [7:0] position_y,
    output hsync,   // ???? ???? ???
    output vsync,   // ???? ???? ???
    output [11:0] rgb // RGB ????? ???? 12 FPGA ??
);
    
    wire video_on;         // ???????? ?????? ???
    wire [9:0] x, y;
    reg [11:0] rgb_reg;
    
    // VGA ?????? ?��???? ????
    vga_controller vga_c(
        .clk(clk), 
        .reset_p(reset_p), 
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
//    .ascii_value(position_x),    // �Է�: ASCII �� ('0'~'9', 'A'~'F')
//    .position_x(position_x)); // ���: �ػ� ���� �� ��ġ �� (0~15)

   
        always @(posedge clk or posedge reset_p) begin
        if (reset_p)
            rgb_reg <= 12'b0; // ???? ?? RGB ????????? 0???? ????
            
        else begin
            if ((x >= position_x * 40) && (x < position_x * 40 + 40) &&
                y >= (position_y * 30) && y < (position_y * 30 + 30)) begin
                rgb_reg <= 12'b111111111111;
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
    input [7:0] ascii_value,    // �Է�: ASCII �� ('0'~'9', 'A'~'F')
    output reg [7:0] position_x // ���: �ػ� ���� �� ��ġ �� (0~640)
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
    input clk,   // from FPGA
    input reset_p,        // system reset
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
	
	always @(posedge clk or posedge reset_p)
		if(reset_p)
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
    always @(posedge clk or posedge reset_p)
        if(reset_p) begin
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
    always @(posedge w_25MHz or posedge reset_p)      // pixel tick
        if(reset_p)
            h_count_next = 0;
        else
            if(h_count_reg == HMAX)                 // end of horizontal scan
                h_count_next = 0;
            else
                h_count_next = h_count_reg + 1;         
  
    // Logic for vertical counter
    always @(posedge w_25MHz or posedge reset_p)
        if(reset_p)
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

module ring_counter_fnd(
          input clk, reset_p,
          output reg [3:0] com);
          
          reg [20:0] clk_div;
          always @(posedge clk)clk_div = clk_div  + 1;
          
          wire clk_div_nedge;
          edge_detector_p ed(.clk(clk), .reset_p(reset_p), .cp(clk_div[16]), .n_edge(clk_div_nedge));
          
          always @(posedge clk or posedge reset_p)begin
                  if(reset_p)com = 4'b1110;
                  else if(clk_div_nedge)begin
                        if(com ==  4'b0111)com = 4'b1110;
                        else com = {com[2:0], 1'b1};
                   end
            end
          
   endmodule
 
module fnd_cntr(
          input clk, reset_p,
          input  [15:0] value,
          output [3:0] com,
          output [7:0] seg_7);
          
          ring_counter_fnd rc(clk, reset_p, com) ;
         
        reg [3:0] hex_value;
         always @(posedge clk)begin
                 case(com)
                       4'b1110: hex_value = value[3:0];
                       4'b1101: hex_value = value[7:4];
                       4'b1011: hex_value = value[11:8];
                       4'b0111: hex_value = value[15:12];
                 endcase
         end
         
          
          decoder_7seg dec_7seg(.hex_value(hex_value),  .seg_7(seg_7));
          
    endmodule

module decoder_7seg(
    input [3:0] hex_value,
    output reg [7:0] seg_7);

    always @(hex_value)begin
        case(hex_value)
            //              abcd_efgp
            0  : seg_7 = 8'b0000_0011;  // 0
            1  : seg_7 = 8'b1001_1111;  // 1
            2  : seg_7 = 8'b0010_0101;  // 2
            3  : seg_7 = 8'b0000_1101;  // 3
            4  : seg_7 = 8'b1001_1001;  // 4
            5  : seg_7 = 8'b0100_1001;  // 5
            6  : seg_7 = 8'b0100_0001;  // 6
            7  : seg_7 = 8'b0001_1111;  // 7
            8  : seg_7 = 8'b0000_0001;  // 8
            9  : seg_7 = 8'b0000_1001;  // 9
            10 : seg_7 = 8'b0000_0101;  // a
            11 : seg_7 = 8'b1100_0001;  // b
            12 : seg_7 = 8'b0110_0011;  // C
            13 : seg_7 = 8'b1000_0101;  // d
            14 : seg_7 = 8'b0110_0001;  // E
            15 : seg_7 = 8'b0111_0001;  // F
        endcase
    end

endmodule

module edge_detector_p(
    input clk, reset_p,
    input cp,
    output p_edge, n_edge);

    reg ff_cur, ff_old;
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            ff_cur <= 0;
            ff_old <= 0;
        end
        else begin
            ff_cur <= cp;
            ff_old <= ff_cur;
        end
    end
    
    assign p_edge = ({ff_cur, ff_old} == 2'b10) ? 1 : 0;
    assign n_edge = ({ff_cur, ff_old} == 2'b01) ? 1 : 0;
endmodule
