`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/15 11:06:37
// Design Name: 
// Module Name: Ultrasonic
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
    output [3:0] com,
    output [7:0] distance_X_cm,
    output [7:0] distance_Y_cm,
    output [7:0] seg_7);
    
    HC_SR04_uart_ctnr HC_SR04_cntr_0(.clk(clk), .reset_p(reset_p),
     .hc_sr04_echo(hc_sr04_echo_X), .hc_sr04_trig(hc_sr04_trig_X),
      .distance(distance_X_cm)); // ³»ºÎ ½ÅÈ£ ¿¬°á

    HC_SR04_uart_ctnr HC_SR04_cntr_1(.clk(clk), .reset_p(reset_p),
     .hc_sr04_echo(hc_sr04_echo_Y), .hc_sr04_trig(hc_sr04_trig_Y),
      .distance(distance_Y_cm)); // ³»ºÎ ½ÅÈ£ ¿¬°á
    
     wire [15:0] distance_X_cm_bcd;
     wire [15:0] distance_Y_cm_bcd;

    bin_to_dec bcd_1(.bin({4'b0, distance_X_cm}),  .bcd(distance_X_cm_bcd));
    bin_to_dec bcd_2(.bin(distance_Y_cm[7:0]),  .bcd(distance_Y_cm_bcd));

    // °áÇÕµÈ °ªÀ» »ý¼ºÇÏ´Â ºÎºÐ
    wire [15:0] combined_value;
    assign combined_value = {distance_X_cm_bcd[7:0], distance_Y_cm_bcd[7:0]}; // °áÇÕµÈ 16ºñÆ® °ª

    // FND Á¦¾î ¸ðµâ
    fnd_cntr fnd (
        .clk(clk), 
        .reset_p(reset_p),
        .value(combined_value), // »óÀ§ 8ºñÆ® Ãâ·Â
        .com(com), 
        .seg_7(seg_7)
    );

endmodule

module HC_SR04_uart_ctnr(
    input clk, reset_p, 
    input hc_sr04_echo,
    output reg hc_sr04_trig,
    output reg [21:0] distance);
    
    // Define state 
    parameter S_IDLE                 = 4'b0001;
    parameter S_10US_TTL             = 4'b0010;
    parameter S_WAIT_PEDGE           = 4'b0100;
    parameter S_CALC_DIST            = 4'b1000;
    
    // Define state, next_state value.
    reg [3:0] state, next_state;
    
    // ï¿½ï¿½ï¿½ï¿½ next_stateï¿½ï¿½ state ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ ï¿½Ö´Â°ï¿½?
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
    
    
    // hc_sr04_dataï¿½ï¿½ Negative edge, Positive edge ï¿½ï¿½ï¿?.
    wire hc_sr04_echo_n_edge, hc_sr04_echo_p_edge;
    edge_detector_p edge_detector_0 (.clk(clk), .reset_p(reset_p), .cp(hc_sr04_echo), .n_edge(hc_sr04_echo_n_edge), .p_edge(hc_sr04_echo_p_edge));
    
    // ï¿½ï¿½ï¿½ï¿½ Ãµï¿½Ìµï¿½ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ caseï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½
    // ï¿½ï¿½ ï¿½ï¿½ï¿½Â¿ï¿½ ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½
    
    reg [21:0] echo_time;
    always @(negedge clk or posedge reset_p) begin
        if(reset_p) begin
            next_state = S_IDLE;
            counter_usec_en = 0; 
            echo_time = 0;
            cnt_e = 0;
        end else begin
            case(state)
                S_IDLE : begin        
                    if(counter_usec < 22'd3_000_000) begin
                        counter_usec_en = 1;  
                        hc_sr04_trig = 0;
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

module bin_to_dec(
        input [11:0] bin,
        output reg [15:0] bcd
    );

    reg [3:0] i;
    
    always @(bin) begin
        bcd = 0;
        for (i=0;i<12;i=i+1)begin
            bcd = {bcd[14:0], bin[11-i]};
            if(i < 11 && bcd[3:0] > 4) bcd[3:0] = bcd[3:0] + 3;
            if(i < 11 && bcd[7:4] > 4) bcd[7:4] = bcd[7:4] + 3;
            if(i < 11 && bcd[11:8] > 4) bcd[11:8] = bcd[11:8] + 3;
            if(i < 11 && bcd[15:12] > 4) bcd[15:12] = bcd[15:12] + 3;
        end
    end
endmodule

module fnd_cntr(
    input clk, reset_p,
    input [15:0] value,
    output [3:0] com,
    output [7:0] seg_7);
    
    ring_counter_fnd rc(clk, reset_p, com);
    
    reg [3:0] hex_value;
    always @(posedge clk)begin
        case(com)
            4'b1110: hex_value = value[3:0];
            4'b1101: hex_value = value[7:4];
            4'b1011: hex_value = value[11:8];
            4'b0111: hex_value = value[15:12];
        endcase
    end
    
    decoder_7seg dec_7seg(.hex_value(hex_value), .seg_7(seg_7));
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

module ring_counter_fnd(
    input clk, reset_p,
    output reg [3:0] com);

    reg [20:0] clk_div = 0;
    always @(posedge clk)clk_div = clk_div + 1;
    
    wire clk_div_nedge;
    edge_detector_p ed(.clk(clk), .reset_p(reset_p), .cp(clk_div[16]), .n_edge(clk_div_nedge));


    always @(posedge clk or posedge reset_p)begin
        if(reset_p)com = 4'b1110;
        else if(clk_div_nedge)begin
            if(com == 4'b0111)com = 4'b1110;
            else com = {com[2:0], 1'b1};
        end
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

module sr04_div_58(
    input clk, reset_p,
    input clk_usec, cnt_e,
    output reg [11:0] cm);
    
    reg [5:0] cnt;
    
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)begin
            cnt = 0;
            cm = 0; 
        end
        else if(clk_usec)begin
            if(cnt_e)begin
                if(cnt >= 57)begin
                    cnt = 0;
                    cm = cm + 1;
                end
                else cnt = cnt + 1;
            end
        end
        else if(!cnt_e)begin
            cnt = 0;
            cm = 0;
        end
    end
endmodule