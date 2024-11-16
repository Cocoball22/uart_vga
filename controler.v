`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/17 10:12:03
// Design Name: 
// Module Name: controler
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

module button_cntr(
    input clk, reset_p,
    input btn,
    output btn_pedge, btn_nedge);

    reg [20:0] clk_div = 0;
    always @(posedge clk)clk_div = clk_div + 1;
    
    wire clk_div_nedge;
    edge_detector_p ed_clk(.clk(clk), .reset_p(reset_p), 
        .cp(clk_div[16]), .n_edge(clk_div_nedge));

    reg debounced_btn;
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)debounced_btn = 0;
        else if(clk_div_nedge)debounced_btn = btn;
    end
    
    edge_detector_p ed_btn(.clk(clk), .reset_p(reset_p), 
        .cp(debounced_btn), .n_edge(btn_nedge), .p_edge(btn_pedge));

endmodule

module key_pad_cntr(
    input clk, reset_p,
    input [3:0] row,
    output reg [3:0] col,
    output reg [3:0] key_value,
    output reg key_valid);

    reg [19:0] clk_div;
    always @(posedge clk)clk_div = clk_div + 1;
    wire clk_8msec_p, clk_8msec_n;
    edge_detector_p ed(.clk(clk), .reset_p(reset_p), 
        .cp(clk_div[19]), .n_edge(clk_8msec_n), .p_edge(clk_8msec_p));
        
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)col = 4'b0001;
        else if(clk_8msec_p && !key_valid)begin
            case(col)
                4'b0001: col = 4'b0010;
                4'b0010: col = 4'b0100;
                4'b0100: col = 4'b1000;
                4'b1000: col = 4'b0001;
                default: col = 4'b0001;
            endcase
        end
    end
    
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            key_value = 0;
            key_valid = 0;
        end
        else begin
            if(clk_8msec_n)begin
                if(row)begin
                    key_valid = 1;
                    case({col, row})
                        8'b0001_0001: key_value = 4'h0;
                        8'b0001_0010: key_value = 4'h1;
                        8'b0001_0100: key_value = 4'h2;
                        8'b0001_1000: key_value = 4'h3;
                        8'b0010_0001: key_value = 4'h4;
                        8'b0010_0010: key_value = 4'h5;
                        8'b0010_0100: key_value = 4'h6;
                        8'b0010_1000: key_value = 4'h7;
                        8'b0100_0001: key_value = 4'h8;
                        8'b0100_0010: key_value = 4'h9;
                        8'b0100_0100: key_value = 4'ha;
                        8'b0100_1000: key_value = 4'hb;
                        8'b1000_0001: key_value = 4'hc;
                        8'b1000_0010: key_value = 4'hd;
                        8'b1000_0100: key_value = 4'he;
                        8'b1000_1000: key_value = 4'hf;
                    endcase
                end
                else begin
                    key_valid = 0;
                    key_value = 0;
                end
            end
        end
    end

endmodule

module keypad_cntr_FSM(
    input clk, reset_p,
    input [3:0] row,
    output reg [3:0] col,
    output reg [3:0] key_value,
    output reg key_valid);
    
    parameter SCAN0 =       5'b00001;
    parameter SCAN1 =       5'b00010;
    parameter SCAN2 =       5'b00100;
    parameter SCAN3 =       5'b01000;
    parameter KEY_PROCESS = 5'b10000;

    reg [19:0] clk_div;
    always @(posedge clk)clk_div = clk_div + 1;
    wire clk_8msec_p, clk_8msec_n;
    edge_detector_p ed(.clk(clk), .reset_p(reset_p), 
        .cp(clk_div[19]), .p_edge(clk_8msec_p), .n_edge(clk_8msec_n) );
        
    reg [4:0] state, next_state;
    
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)state = SCAN0;
        else if(clk_8msec_n)state = next_state;
    end
    
    always @* begin
        case(state)
            SCAN0: begin
                if(row == 0)next_state = SCAN1;
                else next_state = KEY_PROCESS;
            end
            SCAN1: begin
                if(row == 0)next_state = SCAN2;
                else next_state = KEY_PROCESS;
            end
            SCAN2: begin
                if(row == 0)next_state = SCAN3;
                else next_state = KEY_PROCESS;
            end
            SCAN3: begin
                if(row == 0)next_state = SCAN0;
                else next_state = KEY_PROCESS;
            end
            KEY_PROCESS: begin
                if(row == 0)next_state = SCAN0;
                else next_state = KEY_PROCESS;
            end
            default: next_state = SCAN0;
        endcase
    end
    
    always @(posedge clk or posedge reset_p) begin
        if(reset_p)begin
            key_value = 0;
            key_valid = 0;
            col = 0;
        end
        else if(clk_8msec_p)begin
            case(state)
                SCAN0:begin col = 4'b0001; key_valid = 0; end
                SCAN1:begin col = 4'b0010; key_valid = 0; end
                SCAN2:begin col = 4'b0100; key_valid = 0; end
                SCAN3:begin col = 4'b1000; key_valid = 0; end
                KEY_PROCESS: begin
                    key_valid = 1; 
                    case({col, row})
                        8'b0001_0001: key_value = 4'hd; //d
                        8'b0001_0010: key_value = 4'hF; //F
                        8'b0001_0100: key_value = 4'h0; //0
                        8'b0001_1000: key_value = 4'hC; //C
                        8'b0010_0001: key_value = 4'hE; //E
                        8'b0010_0010: key_value = 4'h3; //3
                        8'b0010_0100: key_value = 4'h2; //2
                        8'b0010_1000: key_value = 4'h1; //1
                        8'b0100_0001: key_value = 4'hb; //b
                        8'b0100_0010: key_value = 4'h6; //6
                        8'b0100_0100: key_value = 4'h5; //5
                        8'b0100_1000: key_value = 4'h4; //4
                        8'b1000_0001: key_value = 4'hA; //A
                        8'b1000_0010: key_value = 4'h9; //9
                        8'b1000_0100: key_value = 4'h8; //8
                        8'b1000_1000: key_value = 4'h7; //7
                    endcase
                end
            endcase
        end
    end
endmodule

module dht11_cntr(
    input clk, reset_p,
    inout dht11_data,
    output reg [7:0] humidity, temperature,
    output [15:0] led_debug);
    
    parameter S_IDLE = 6'b00_0001;
    parameter S_LOW_18MS = 6'b00_0010;
    parameter S_HIGH_20US = 6'b00_0100;
    parameter S_LOW_80US = 6'b00_1000;
    parameter S_HIGH_80US = 6'b01_0000;
    parameter S_READ_DATA = 6'b10_0000;
    
    parameter S_WAIT_PEDGE = 2'b01;
    parameter S_WAIT_NEDGE = 2'b10;
    
    reg [5:0] state, next_state;
    reg [1:0] read_state;
    
    assign led_debug[5:0] = state;
    
    wire clk_usec;
    clock_div_100 usec_clk(.clk(clk), .reset_p(reset_p), .clk_div_100_nedge(clk_usec));

    reg [21:0] count_usec;
    reg count_usec_e;
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)count_usec = 0;
        else if(clk_usec && count_usec_e)count_usec = count_usec + 1;
        else if(!count_usec_e)count_usec = 0;
    end
    
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)state = S_IDLE;
        else state = next_state;
    end
    
    reg dht11_buffer;
    assign dht11_data = dht11_buffer;
    
    wire dht_pedge, dht_nedge;
    edge_detector_p ed(.clk(clk), .reset_p(reset_p), 
        .cp(dht11_data), .p_edge(dht_pedge), .n_edge(dht_nedge) );
    
    reg [39:0] temp_data, rcv_data;
    reg [5:0] data_count;
    reg [5:0] data_count_temp;
    assign led_debug[11:6] = data_count_temp;
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            next_state = S_IDLE;
            read_state = S_WAIT_PEDGE;
            temp_data = 0;
            rcv_data = 0;
            data_count = 0;
        end
        else begin
            case(state)
                S_IDLE:begin
                    if(count_usec < 22'd3_000_000)begin  //22'd3_000_000
                        count_usec_e = 1;
                        dht11_buffer = 'bz;
                    end
                    else begin
                        count_usec_e = 0;
                        next_state = S_LOW_18MS;
                    end
                end
                S_LOW_18MS:begin
                    if(count_usec < 22'd20_000)begin
                        dht11_buffer = 0;
                        count_usec_e = 1;
                    end
                    else begin
                        count_usec_e = 0;
                        next_state = S_HIGH_20US;
                        dht11_buffer = 'bz;
                    end
                end
                S_HIGH_20US:begin
                    count_usec_e = 1;
                    if(count_usec > 22'd100_000)begin
                        next_state = S_IDLE;
                        count_usec_e = 0;
                    end
                    else if(dht_nedge)begin
                        count_usec_e = 0;
                        next_state = S_LOW_80US;
                    end
                end
                S_LOW_80US:begin
                count_usec_e = 1;
                    if(count_usec > 22'd100_000)begin
                        next_state = S_IDLE;
                        count_usec_e = 0;
                    end
                    else if(dht_pedge)begin
                        next_state = S_HIGH_80US;
                        count_usec_e = 0;
                    end
                end
                S_HIGH_80US:begin
                    count_usec_e = 1;
                    if(count_usec > 22'd100_000)begin
                        next_state = S_IDLE;
                        count_usec_e = 0;
                    end
                    else if(dht_nedge)begin
                        next_state = S_READ_DATA;
                        count_usec_e = 0;
                    end
                end
                S_READ_DATA:begin
                    count_usec_e = 1;
                    if(count_usec > 22'd100_000)begin
                        next_state = S_IDLE;
                        count_usec_e = 0;
                        data_count = 0;
                        read_state = S_WAIT_PEDGE;
                    end
                    case(read_state)
                        S_WAIT_PEDGE:begin
                            if(dht_pedge)read_state = S_WAIT_NEDGE;
                        end
                        S_WAIT_NEDGE:begin
                            if(dht_nedge)begin
                                if(count_usec < 95)begin
                                    temp_data = {temp_data[38:0], 1'b0};
                                end
                                else begin
                                    temp_data = {temp_data[38:0], 1'b1};
                                end
                                data_count = data_count + 1;
                                read_state = S_WAIT_PEDGE;
                                count_usec_e = 0;
                            end
                            else begin
                                count_usec_e = 1;
                            end
                        end
                    endcase
                    if(data_count >= 40)begin
                        data_count = 0;
                        next_state = S_IDLE;
                        read_state = S_WAIT_PEDGE;
                        count_usec_e = 0;
                        rcv_data = temp_data;
//                        if(temp_data[39:32] + temp_data[31:24] + temp_data[23:16] + temp_data[15:8] == temp_data[7:0])begin
//                            humidity = temp_data[39:32];
//                            temperature = temp_data[23:16];
//                        end
                    end
                end
                default:next_state = S_IDLE;
            endcase
        end
    end
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            humidity = 0;
            temperature = 0;
        end
        else begin
            if(rcv_data[39:32] + rcv_data[31:24] + rcv_data[23:16] + rcv_data[15:8] == temp_data[7:0])begin
                humidity = rcv_data[39:32];
                temperature = rcv_data[23:16];
            end
        end
    end
    
    
endmodule

module HC_SR04_cntr_JBH (
    input clk, reset_p, 
    input hc_sr04_echo,
    output reg hc_sr04_trig,
    output reg [21:0] distance,
    output [7:0] led_debug);
    
    // Define state 
    parameter S_IDLE                 = 4'b0001;
    parameter S_10US_TTL             = 4'b0010;
    parameter S_WAIT_PEDGE           = 4'b0100;
    parameter S_CALC_DIST            = 4'b1000;
    
    // Define state, next_state value.
    reg [3:0] state, next_state;
    
    // For Test
    assign led_debug[3:0] = state;
    
    // ���� next_state�� state ������ �ִ°�?
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) state = S_IDLE;
        else state = next_state;
    end
    
    // get 10us negative one cycle pulse
    wire clk_usec;
    clock_div_100   usec_clk( .clk(clk), .reset_p(reset_p), .clk_div_100_nedge(clk_usec));     // 1us
    
    // making usec counter.
    reg [21:0] counter_usec;
    reg counter_usec_en;
    
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin counter_usec = 0;
        end else if(clk_usec && counter_usec_en) counter_usec = counter_usec + 1;
        else if(!counter_usec_en) counter_usec = 0;
    end
    
    
    // hc_sr04_data�� Negative edge, Positive edge ���.
    wire hc_sr04_echo_n_edge, hc_sr04_echo_p_edge;
    edge_detector_p edge_detector_0 (.clk(clk), .reset_p(reset_p), .cp(hc_sr04_echo), .n_edge(hc_sr04_echo_n_edge), .p_edge(hc_sr04_echo_p_edge));
    
    // ���� õ�̵��� ���� case�� ����
    // �� ���¿� ���� ���� ����
    always @(negedge clk or posedge reset_p) begin
        if(reset_p) begin
            next_state = S_IDLE;
            counter_usec_en = 0;  
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
                         counter_usec_en = 1;
                    end     
                S_CALC_DIST : begin          
                     if(hc_sr04_echo_n_edge) begin
                                distance = counter_usec / 58;
                                counter_usec_en = 0;
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

module HC_SR04_cntr(
    input clk, reset_p, 
    input hc_sr04_echo,
    output reg hc_sr04_trig,
    output reg [21:0] distance,
    output [7:0] led_debug);
    
    // Define state 
    parameter S_IDLE                 = 4'b0001;
    parameter S_10US_TTL             = 4'b0010;
    parameter S_WAIT_PEDGE           = 4'b0100;
    parameter S_CALC_DIST            = 4'b1000;
    
    // Define state, next_state value.
    reg [3:0] state, next_state;
    
    // For Test
    assign led_debug[3:0] = state;
    
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
    
    
    // hc_sr04_data�� Negative edge, Positive edge ���.
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
    
//    always @(posedge clk or posedge reset_p)begin
//        if(reset_p)distance = 0;
//        else begin
//            if(echo_time < 174)distance = 2;
//            else if(echo_time < 232)distance = 3;
//            else if(echo_time < 290)distance = 4;
//            else if(echo_time < 348)distance = 5;
//            else if(echo_time < 406)distance = 6;
//            else if(echo_time < 464)distance = 7;
//            else if(echo_time < 522)distance = 8;
//            else if(echo_time < 580)distance = 9;
//            else if(echo_time < 638)distance = 10;
//            else if(echo_time < 696)distance = 11;
//            else if(echo_time < 754)distance = 12;
//            else if(echo_time < 812)distance = 13;
//            else if(echo_time < 870)distance = 14;
//            else if(echo_time < 928)distance = 15;
//            else if(echo_time < 986)distance = 16;
//            else if(echo_time < 1044)distance = 17;
//            else if(echo_time < 1102)distance = 18;
//            else if(echo_time < 1160)distance = 19;
//            else if(echo_time < 1218)distance = 20;
//            else if(echo_time < 1276)distance = 21;
//            else if(echo_time < 1334)distance = 22;
//            else if(echo_time < 1392)distance = 23;
//            else if(echo_time < 1450)distance = 24;
//            else if(echo_time < 1508)distance = 25;
//            else if(echo_time < 1566)distance = 26;
//            else if(echo_time < 1624)distance = 27;
//            else if(echo_time < 1682)distance = 28;
//            else if(echo_time < 1740)distance = 29;
//            else if(echo_time < 1798)distance = 30;
//            else if(echo_time < 1856)distance = 31;
//            else if(echo_time < 1914)distance = 32;
//            else if(echo_time < 1972)distance = 33;
//            else if(echo_time < 2030)distance = 34;
//            else distance = 35;
            
//        end
//    end
    
    
endmodule

module pwm_100step(
    input clk, reset_p,
    input [6:0] duty,
    output pwm);
    
    parameter sys_clk_freq = 100_000_000;
    parameter pwm_freq = 10_000; // The pwm frequency operates at 10khz to prevent the frequency from being too low
    parameter duty_step = 100; 
    parameter temp = sys_clk_freq / duty_step / pwm_freq;
    parameter temp_half = temp / 2;
    
    // Created pwm_freq, where 100ns is one cycle.
    integer cnt_sysclk;
    wire pwm_freqX100;
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)cnt_sysclk = 0;
        else begin
            if(cnt_sysclk >= temp-1) cnt_sysclk = 0;
            else cnt_sysclk = cnt_sysclk + 1;
        end
    end
    
    assign pwm_freqX100 = (cnt_sysclk < temp_half) ? 1 : 0;
    wire pwm_freqX100_nedge;
    edge_detector_n ed(
        .clk(clk), .reset_p(reset_p), .cp(pwm_freqX100),
        .n_edge(pwm_freqX100_nedge));

    reg [6:0] cnt_duty;
    
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)cnt_duty = 0;
        else if(pwm_freqX100_nedge)begin
            if(cnt_duty >= 99)cnt_duty = 0;
            else cnt_duty = cnt_duty + 1;
        end
    end
    
    assign pwm = (cnt_duty < duty) ? 1 : 0;

endmodule

module pwm_Nstep_freq
#(
    parameter sys_clk_freq = 100_000_000,
    parameter pwm_freq = 10_000, // Set pwm frequency
    parameter duty_step = 100,  //  Set duty_step
    parameter temp = sys_clk_freq / duty_step / pwm_freq,
    parameter temp_half = temp / 2)
(
    input clk, reset_p,
    input [31:0] duty,
    output pwm);
    
    /* As the duty step increases, it decreases in ns units, and as the duty step decreases, 
    it increases in ns units. Since it operates as a system clock anyway,*/
    integer cnt_sysclk;
    wire clk_freqXstep;
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)cnt_sysclk = 0;
        else begin
            if(cnt_sysclk >= temp-1) cnt_sysclk = 0;
            else cnt_sysclk = cnt_sysclk + 1;
        end
    end
    
    assign clk_freqXstep = (cnt_sysclk < temp_half) ? 1 : 0;
    
    wire clk_freqXstep_nedge;
    edge_detector_n ed(
        .clk(clk), .reset_p(reset_p), .cp(clk_freqXstep),
        .n_edge(clk_freqXstep_nedge));

    integer cnt_duty;
    
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)cnt_duty = 0;
        else if(clk_freqXstep_nedge)begin
            if(cnt_duty >= (duty_step-1))cnt_duty = 0;
            else cnt_duty = cnt_duty + 1;
        end
    end
    
    assign pwm = (cnt_duty < duty) ? 1 : 0;

endmodule

module I2C_master(
    input clk, reset_p,
    input [6:0] addr,
    input rd_wr,
    input [7:0] data,
    input comm_go,
    output reg scl, sda,
    output reg [15:0] led);
    
    parameter IDLE = 7'b000_0001;
    parameter COMM_START = 7'b000_0010;
    parameter SEND_ADDR = 7'b000_0100;
    parameter RD_ACK = 7'b000_1000;
    parameter SEND_DATA = 7'b001_0000;
    parameter SCL_STOP = 7'b010_0000;
    parameter COMM_STOP = 7'b100_0000;
    
    wire [7:0] addr_rw;
    assign addr_rw = {addr, rd_wr};
    
    wire clk_usec;
    clock_div_100 usec_clk(.clk(clk), .reset_p(reset_p), 
        .clk_div_100_nedge(clk_usec));
    
    reg [2:0] count_usec5;
    reg scl_e;
    
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            count_usec5 = 0;
            scl = 1;
        end
        else if(scl_e)begin
            if(clk_usec)begin
                if(count_usec5 >= 4)begin
                    count_usec5 = 0;
                    scl = ~scl;
                end
                else count_usec5 = count_usec5 + 1;
            end
        end
        else if(!scl_e)begin
            scl = 1;
            count_usec5 = 0;
        end
    end
    
    wire scl_nedge, scl_pedge;
    edge_detector_n ed(
        .clk(clk), .reset_p(reset_p), .cp(scl),
        .n_edge(scl_nedge), .p_edge(scl_pedge));
        
    wire comm_go_pedge;
    edge_detector_n ed_go(
        .clk(clk), .reset_p(reset_p), .cp(comm_go),
        .p_edge(comm_go_pedge));
        
    reg [6:0] state, next_state;
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)state = IDLE;
        else state = next_state;
    end
    reg [2:0] cnt_bit;
    reg stop_flag;
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            next_state = IDLE;
            scl_e = 0;
            sda = 1;
            cnt_bit = 7;
            stop_flag = 0;
        end
        else begin
            case(state)
                IDLE:begin
                    scl_e = 0;
                    sda = 1;
                    if(comm_go_pedge)next_state = COMM_START;
                end
                COMM_START:begin
                    sda = 0;
                    scl_e = 1;
                    next_state = SEND_ADDR;
                end
                SEND_ADDR:begin
                    if(scl_nedge)sda = addr_rw[cnt_bit];
                    if(scl_pedge)begin
                        if(cnt_bit == 0)begin
                            cnt_bit = 7;
                            next_state = RD_ACK;
                        end
                        else cnt_bit = cnt_bit - 1;
                    end
                end
                RD_ACK:begin
                    if(scl_nedge)sda = 'bz;
                    else if(scl_pedge)begin
                        if(stop_flag)begin
                            stop_flag = 0;
                            next_state = SCL_STOP;
                        end
                        else begin
                            stop_flag = 1;
                            next_state = SEND_DATA;
                        end
                    end
                end
                SEND_DATA:begin
                    if(scl_nedge)sda = data[cnt_bit];
                    if(scl_pedge)begin
                        if(cnt_bit == 0)begin
                            cnt_bit = 7;
                            next_state = RD_ACK;
                        end
                        else cnt_bit = cnt_bit - 1;
                    end
                end
                SCL_STOP:begin
                    if(scl_nedge)sda = 0;
                    else if(scl_pedge)next_state = COMM_STOP;
                end
                COMM_STOP:begin
                    if(count_usec5 >= 3)begin
                        scl_e = 0;
                        sda = 1;
                        next_state = IDLE;
                    end
                end
                
            endcase 
        end
    end
endmodule

module i2c_lcd_send_byte(
    input clk, reset_p,
    input [6:0] addr,
    input [7:0] send_buffer,
    input rs, send,
    output scl, sda,
    output reg busy,
    output [15:0] led);

    parameter IDLE                      = 6'b00_0001;
    parameter SEND_HIGH_NIBBLE_DISABLE  = 6'b00_0010;
    parameter SEND_HIGH_NIBBLE_ENABLE   = 6'b00_0100;
    parameter SEND_LOW_NIBBLE_DISABLE   = 6'b00_1000;
    parameter SEND_LOW_NIBBLE_ENABLE    = 6'b01_0000;
    parameter SEND_DISABLE              = 6'b10_0000;
    
    reg [7:0] data;
    reg comm_go;
    
    wire send_pedge;
    edge_detector_n ed_go(
        .clk(clk), .reset_p(reset_p), .cp(send),
        .p_edge(send_pedge));
    
    wire clk_usec;
    clock_div_100 usec_clk(.clk(clk), .reset_p(reset_p), 
        .clk_div_100_nedge(clk_usec));
        
    reg [21:0] count_usec;
    reg count_usec_e;
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)count_usec = 0;
        else if(clk_usec && count_usec_e)count_usec = count_usec + 1;
        else if(!count_usec_e)count_usec = 0;
    end
    
    reg [5:0] state, next_state;
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)state = IDLE;
        else state = next_state;
    end
    
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            next_state = IDLE;
            busy = 0;
            comm_go = 0;
            data = 0;
            count_usec_e = 0;
        end
        else begin
            case(state)
                IDLE:begin
                    if(send_pedge)begin
                        next_state = SEND_HIGH_NIBBLE_DISABLE;
                        busy = 1;
                    end
                end
                SEND_HIGH_NIBBLE_DISABLE:begin
                    if(count_usec <= 22'd200)begin
                        data = {send_buffer[7:4], 3'b100, rs}; // [d7 d6 d5 d4], BT, E, RW, RS
                        comm_go = 1;
                        count_usec_e = 1;
                    end
                    else begin
                        count_usec_e = 0;
                        comm_go = 0;
                        next_state = SEND_HIGH_NIBBLE_ENABLE;
                    end
                end
                SEND_HIGH_NIBBLE_ENABLE:begin
                    if(count_usec <= 22'd200)begin
                        data = {send_buffer[7:4], 3'b110, rs}; // [d7 d6 d5 d4], BT, E, RW, RS
                        comm_go = 1;
                        count_usec_e = 1;
                    end
                    else begin
                        count_usec_e = 0;
                        comm_go = 0;
                        next_state = SEND_LOW_NIBBLE_DISABLE;
                    end
                end
                SEND_LOW_NIBBLE_DISABLE:begin
                    if(count_usec <= 22'd200)begin
                        data = {send_buffer[3:0], 3'b100, rs}; // [d7 d6 d5 d4], BT, E, RW, RS
                        comm_go = 1;
                        count_usec_e = 1;
                    end
                    else begin
                        count_usec_e = 0;
                        comm_go = 0;
                        next_state = SEND_LOW_NIBBLE_ENABLE;
                    end
                end
                SEND_LOW_NIBBLE_ENABLE:begin
                    if(count_usec <= 22'd200)begin
                        data = {send_buffer[3:0], 3'b110, rs}; // [d7 d6 d5 d4], BT, E, RW, RS
                        comm_go = 1;
                        count_usec_e = 1;
                    end
                    else begin
                        count_usec_e = 0;
                        comm_go = 0;
                        next_state = SEND_DISABLE;
                    end
                end
                SEND_DISABLE:begin
                    if(count_usec <= 22'd200)begin
                        data = {send_buffer[3:0], 3'b100, rs}; // [d7 d6 d5 d4], BT, E, RW, RS
                        comm_go = 1;
                        count_usec_e = 1;
                    end
                    else begin
                        count_usec_e = 0;
                        comm_go = 0;
                        next_state = IDLE;
                        busy = 0;
                    end
                end
            endcase
        end
    end
    
    I2C_master master(.clk(clk), .reset_p(reset_p),
        .addr(addr),
        .rd_wr(0),
        .data(data),
        .comm_go(comm_go),
        .scl(scl), .sda(sda),
        .led(led));

endmodule


































