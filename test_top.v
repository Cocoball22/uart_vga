`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/16 14:15:29
// Design Name: 
// Module Name: test_top
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


module board_led_switch_test_top(
    input [15:0] switch,
    output [15:0] led);
    
    assign led = switch;
endmodule

module fnd_test_top(
    input clk, reset_p,
    input [15:0] switch,
    output [3:0] com,
    output [7:0] seg_7);
    
    fnd_cntr fnd(.clk(clk), .reset_p(reset_p), .value(switch), .com(com), .seg_7(seg_7));
    
endmodule

module watch_top(
    input clk, reset_p,
    input [2:0] btn,
    output [3:0] com,
    output [7:0] seg_7);
    
    wire btn_mode;
    wire btn_sec;
    wire btn_min;
    wire set_watch;    
    wire inc_sec, inc_min;
    wire clk_usec, clk_msec, clk_sec, clk_min;
    wire [3:0] sec1, sec10, min1, min10;    
    wire [15:0] value;
    
    button_cntr btn0(.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_mode));
    button_cntr btn1(.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(btn_sec));
    button_cntr btn2(.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(btn_min));
    
    T_flip_flop_p t_mode(.clk(clk), .reset_p(reset_p), .t(btn_mode), .q(set_watch));
    
    assign inc_sec = set_watch ? btn_sec : clk_sec;
    assign inc_min = set_watch ? btn_min : clk_min;

    clock_div_100 usec_clk(.clk(clk), .reset_p(reset_p), .clk_div_100(clk_usec));
    clock_div_1000 msec_clk(.clk(clk), .reset_p(reset_p), 
        .clk_source(clk_usec), .clk_div_1000(clk_msec));
    clock_div_1000 sec_clk(.clk(clk), .reset_p(reset_p), 
        .clk_source(clk_msec), .clk_div_1000_nedge(clk_sec));
    clock_div_60 min_clk(.clk(clk), .reset_p(reset_p), 
        .clk_source(inc_sec), .clk_div_60_nedge(clk_min));
        
    counter_bcd_60 counter_sec(.clk(clk), .reset_p(reset_p), 
        .clk_time(inc_sec), .bcd1(sec1), .bcd10(sec10));
    counter_bcd_60 counter_min(.clk(clk), .reset_p(reset_p), 
        .clk_time(inc_min), .bcd1(min1), .bcd10(min10));
    
    assign value = {min10, min1, sec10, sec1};    
    fnd_cntr fnd(.clk(clk), .reset_p(reset_p), .value(value), .com(com), .seg_7(seg_7));

endmodule

module loadable_watch_top(
    input clk, reset_p,
    input [2:0] btn,
    output [3:0] com,
    output [7:0] seg_7);
    
    wire btn_mode;
    wire btn_sec;
    wire btn_min;
    wire set_watch;    
    wire inc_sec, inc_min;
    wire clk_usec, clk_msec, clk_sec, clk_min;
    
    
    
    button_cntr btn0(.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_mode));
    button_cntr btn1(.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(btn_sec));
    button_cntr btn2(.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(btn_min));
    
    T_flip_flop_p t_mode(.clk(clk), .reset_p(reset_p), .t(btn_mode), .q(set_watch));
    
    wire watch_load_en, set_load_en;
    edge_detector_n ed_source(
        .clk(clk), .reset_p(reset_p), .cp(set_watch),
        .n_edge(watch_load_en), .p_edge(set_load_en));
    
    assign inc_sec = set_watch ? btn_sec : clk_sec;
    assign inc_min = set_watch ? btn_min : clk_min;

    clock_div_100 usec_clk(.clk(clk), .reset_p(reset_p), .clk_div_100(clk_usec));
    clock_div_1000 msec_clk(.clk(clk), .reset_p(reset_p), 
        .clk_source(clk_usec), .clk_div_1000(clk_msec));
    clock_div_1000 sec_clk(.clk(clk), .reset_p(reset_p), 
        .clk_source(clk_msec), .clk_div_1000_nedge(clk_sec));
    clock_div_60 min_clk(.clk(clk), .reset_p(reset_p), 
        .clk_source(inc_sec), .clk_div_60_nedge(clk_min));
        
    loadable_counter_bcd_60 sec_watch(
        .clk(clk), .reset_p(reset_p),
        .clk_time(clk_sec),
        .load_enable(watch_load_en),
        .load_bcd1(set_sec1), .load_bcd10(set_sec10),
        .bcd1(watch_sec1), .bcd10(watch_sec10));
    loadable_counter_bcd_60 min_watch(
        .clk(clk), .reset_p(reset_p),
        .clk_time(clk_min),
        .load_enable(watch_load_en),
        .load_bcd1(set_min1), .load_bcd10(set_min10),
        .bcd1(watch_min1), .bcd10(watch_min10));
        
    loadable_counter_bcd_60 sec_set(
        .clk(clk), .reset_p(reset_p),
        .clk_time(btn_sec),
        .load_enable(set_load_en),
        .load_bcd1(watch_sec1), .load_bcd10(watch_sec10),
        .bcd1(set_sec1), .bcd10(set_sec10));
    loadable_counter_bcd_60 min_set(
        .clk(clk), .reset_p(reset_p),
        .clk_time(btn_min),
        .load_enable(set_load_en),
        .load_bcd1(watch_min1), .load_bcd10(watch_min10),
        .bcd1(set_min1), .bcd10(set_min10));
    wire [15:0] value, watch_value, set_value;    
    wire [3:0] watch_sec1, watch_sec10, watch_min1, watch_min10; 
    wire [3:0] set_sec1, set_sec10, set_min1, set_min10;    
    assign watch_value = {watch_min10, watch_min1, watch_sec10, watch_sec1};
    assign set_value = {set_min10, set_min1, set_sec10, set_sec1}; 
    assign value = set_watch ? set_value : watch_value;   
    fnd_cntr fnd(.clk(clk), .reset_p(reset_p), .value(value), .com(com), .seg_7(seg_7));

endmodule

module stop_watch_top(
    input clk, reset_p,
    input [2:0] btn,
    output [3:0] com,
    output [7:0] seg_7,
    output led_start, led_lap);
    
    wire clk_start;
    wire start_stop;
    reg lap;
    wire clk_usec, clk_msec, clk_sec, clk_min;
    wire btn_start, btn_lap, btn_clear;    
    wire reset_start;
    assign clk_start = start_stop ? clk : 0;

    clock_div_100 usec_clk(.clk(clk_start), .reset_p(reset_start), .clk_div_100(clk_usec));
    clock_div_1000 msec_clk(.clk(clk_start), .reset_p(reset_start), 
        .clk_source(clk_usec), .clk_div_1000(clk_msec));
    clock_div_1000 sec_clk(.clk(clk_start), .reset_p(reset_start), 
        .clk_source(clk_msec), .clk_div_1000_nedge(clk_sec));
    clock_div_60 min_clk(.clk(clk_start), .reset_p(reset_start), 
        .clk_source(clk_sec), .clk_div_60_nedge(clk_min));
    
    button_cntr btn0(.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_start));
    button_cntr btn1(.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(btn_lap));
    button_cntr btn2(.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(btn_clear));
    
    
    assign reset_start = reset_p | btn_clear;
    
    T_flip_flop_p t_start(.clk(clk), .reset_p(reset_start), .t(btn_start), .q(start_stop));
    assign led_start = start_stop;
    
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)lap = 0;
        else begin
            if(btn_lap) lap = ~lap;
            else if(btn_clear) lap = 0;
        end
    end
    
    assign led_lap = lap;
    
    wire [3:0] min10, min1, sec10, sec1;   
    counter_bcd_60_clear counter_sec(.clk(clk), .reset_p(reset_p), 
        .clk_time(clk_sec), .clear(btn_clear), .bcd1(sec1), .bcd10(sec10));
    counter_bcd_60_clear counter_min(.clk(clk), .reset_p(reset_p), 
        .clk_time(clk_min), .clear(btn_clear), .bcd1(min1), .bcd10(min10));
        
    reg [15:0] lap_time;
    wire [15:0] cur_time;
    assign cur_time = {min10, min1, sec10, sec1};
    always @(posedge clk or posedge reset_p)begin
        if(reset_p) lap_time = 0;
        else if(btn_lap) lap_time = cur_time;
        else if(btn_clear) lap_time = 0;
    end    
        
    wire [15:0] value;    
    assign value = lap ? lap_time : cur_time;   
    fnd_cntr fnd(.clk(clk), .reset_p(reset_p), .value(value), .com(com), .seg_7(seg_7));    

endmodule

module stop_watch_csec_top(
    input clk, reset_p,
    input [2:0] btn,
    output [3:0] com,
    output [7:0] seg_7,
    output led_start, led_lap);
    
    wire clk_start;
    wire start_stop;
    reg lap;
    wire clk_usec, clk_msec, clk_csec, clk_sec, clk_min;
    wire btn_start, btn_lap, btn_clear;    
    wire reset_start;
    assign clk_start = start_stop ? clk : 0;

    clock_div_100 usec_clk(.clk(clk_start), .reset_p(reset_start), .clk_div_100(clk_usec));
    clock_div_1000 msec_clk(.clk(clk_start), .reset_p(reset_start), 
        .clk_source(clk_usec), .clk_div_1000(clk_msec));
    clock_div_10_LKM(.clk(clk), .reset_p(reset_p), .clk_source(clk_msec),
        .clk_div_10_nedge(clk_csec));
    clock_div_1000 sec_clk(.clk(clk_start), .reset_p(reset_start), 
        .clk_source(clk_msec), .clk_div_1000_nedge(clk_sec));
    clock_div_60 min_clk(.clk(clk_start), .reset_p(reset_start), 
        .clk_source(clk_sec), .clk_div_60_nedge(clk_min));
    
    button_cntr btn0(.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_start));
    button_cntr btn1(.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(btn_lap));
    button_cntr btn2(.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(btn_clear));
    
    
    assign reset_start = reset_p | btn_clear;
    
    T_flip_flop_p t_start(.clk(clk), .reset_p(reset_start), .t(btn_start), .q(start_stop));
    assign led_start = start_stop;
    
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)lap = 0;
        else begin
            if(btn_lap) lap = ~lap;
            else if(btn_clear) lap = 0;
        end
    end
    
    assign led_lap = lap;
    
    wire [3:0] min10, min1, sec10, sec1, csec10, csec1; 
    counter_bcd_100_clear_LHS(.clk(clk), .reset_p(reset_p),
       .clk_time(clk_csec), .clear(btn_clear), .bcd1(csec1), .bcd10(csec10));  
    counter_bcd_60_clear counter_sec(.clk(clk), .reset_p(reset_p), 
        .clk_time(clk_sec), .clear(btn_clear), .bcd1(sec1), .bcd10(sec10));
    counter_bcd_60_clear counter_min(.clk(clk), .reset_p(reset_p), 
        .clk_time(clk_min), .clear(btn_clear), .bcd1(min1), .bcd10(min10));
        
    reg [15:0] lap_time;
    wire [15:0] cur_time;
    assign cur_time = {sec10, sec1, csec10, csec1};
    always @(posedge clk or posedge reset_p)begin
        if(reset_p) lap_time = 0;
        else if(btn_lap) lap_time = cur_time;
        else if(btn_clear) lap_time = 0;
    end    
        
    wire [15:0] value;    
    assign value = lap ? lap_time : cur_time;   
    fnd_cntr fnd(.clk(clk), .reset_p(reset_p), .value(value), .com(com), .seg_7(seg_7));    

endmodule

module cook_timer_top(
    input clk, reset_p,
    input [3:0] btn,
    output [3:0] com,
    output [7:0] seg_7,
    output led_alarm, led_start, buzz);

    wire clk_usec, clk_msec, clk_sec, clk_min;
    clock_div_100 usec_clk(.clk(clk), .reset_p(reset_p), .clk_div_100(clk_usec));
    clock_div_1000 msec_clk(.clk(clk), .reset_p(reset_p), 
        .clk_source(clk_usec), .clk_div_1000(clk_msec));
    clock_div_1000 sec_clk(.clk(clk), .reset_p(reset_p), 
        .clk_source(clk_msec), .clk_div_1000_nedge(clk_sec));
    
    wire btn_start, btn_sec, btn_min, btn_alarm_off;
    button_cntr btn0(.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_start));
    button_cntr btn1(.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(btn_sec));
    button_cntr btn2(.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(btn_min));
    button_cntr btn3(.clk(clk), .reset_p(reset_p), .btn(btn[3]), .btn_pedge(btn_alarm_off));
    
    
    wire [3:0] set_min10, set_min1, set_sec10, set_sec1;
    wire [3:0] cur_min10, cur_min1, cur_sec10, cur_sec1;
    counter_bcd_60 counter_sec(.clk(clk), .reset_p(reset_p), 
        .clk_time(btn_sec), .bcd1(set_sec1), .bcd10(set_sec10));
    counter_bcd_60 counter_min(.clk(clk), .reset_p(reset_p), 
        .clk_time(btn_min), .bcd1(set_min1), .bcd10(set_min10));
        
    wire dec_clk;
    loadable_down_counter_bcd_60 cur_sec(
        .clk(clk), .reset_p(reset_p), .clk_time(clk_sec),
        .load_enable(btn_start),
        .load_bcd1(set_sec1), .load_bcd10(set_sec10),
        .bcd1(cur_sec1), .bcd10(cur_sec10), .dec_clk(dec_clk));
    loadable_down_counter_bcd_60 cur_min(
        .clk(clk), .reset_p(reset_p), .clk_time(dec_clk), 
        .load_enable(btn_start),
        .load_bcd1(set_min1), .load_bcd10(set_min10),
        .bcd1(cur_min1), .bcd10(cur_min10));
    
    wire [15:0] value, set_time, cur_time; 
    assign set_time = {set_min10, set_min1, set_sec10, set_sec1};
    assign cur_time = {cur_min10, cur_min1, cur_sec10, cur_sec1};
    
    reg start_set, alarm; 
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            start_set = 0;
            alarm = 0;
        end
        else begin
            if(btn_start)start_set = ~start_set;
            else if(cur_time == 0 && start_set)begin
                start_set = 0;
                alarm = 1;
            end
            else if(btn_alarm_off) alarm = 0;
        end
    end
    assign led_alarm = alarm;
    assign buzz = alarm;
    assign led_start = start_set;
       
    assign value = start_set ? cur_time : set_time;   
    fnd_cntr fnd(.clk(clk), .reset_p(reset_p), .value(value), .com(com), .seg_7(seg_7));  
    
endmodule

module keypad_test_top(
    input clk, reset_p,
    input [3:0] row,
    output [3:0] col,
    output[3:0] com,
    output [7:0] seg_7,
    output led_key_valid
);

    wire [3:0] key_value;
    wire key_valid;
    keypad_cntr_FSM keypad(.clk(clk), .reset_p(reset_p),
        .row(row), .col(col),
        .key_value(key_value),
        .key_valid(key_valid));
    assign led_key_valid = key_valid;
    
    wire key_valid_p;    
    edge_detector_p ed(.clk(clk), .reset_p(reset_p), 
        .cp(key_valid), .p_edge(key_valid_p));
    
    reg [15:0] key_count;
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)key_count = 0;
        else if(key_valid_p)begin
            if(key_value == 1)key_count = key_count + 1;
            else if(key_value == 2)key_count = key_count - 1;
            else if(key_value == 3)key_count = key_count + 2;
        end
    end
    
    fnd_cntr fnd(.clk(clk), .reset_p(reset_p), 
        .value(key_count), .com(com), .seg_7(seg_7)); 

endmodule

module dht11_test_top(
    input clk, reset_p,
    inout dht11_data,
    output [3:0] com,
    output [7:0] seg_7,
    output [15:0] led_debug);

    wire [7:0] humidity, temperature;
    dht11_cntr dht11(.clk(clk), .reset_p(reset_p),
        .dht11_data(dht11_data),
        .humidity(humidity), .temperature(temperature), .led_debug(led_debug));
    
    
    
    wire [15:0] humidity_bcd, temperature_bcd;
    bin_to_dec bcd_humi(.bin({4'b0, humidity}), .bcd(humidity_bcd));
    bin_to_dec bcd_tmpr(.bin({4'b0, temperature}), .bcd(temperature_bcd));
    wire [15:0] value;
    assign value = {humidity_bcd[7:0], temperature_bcd[7:0]};
    fnd_cntr fnd(.clk(clk), .reset_p(reset_p), 
        .value(value), .com(com), .seg_7(seg_7)); 

endmodule

module HC_SR04_top (
    input clk, reset_p, 
    input hc_sr04_echo,
    output hc_sr04_trig,
    output [3:0] com,
    output [7:0] seg_7, led_debug) ;

    wire [21:0] distance_cm;
    HC_SR04_cntr HC_SR04_cntr_0(.clk(clk), .reset_p(reset_p), 
        .hc_sr04_echo(hc_sr04_echo), .hc_sr04_trig(hc_sr04_trig), 
        .distance(distance_cm),  .led_debug(led_debug)); 

    wire [15:0] distance_cm_bcd;
    bin_to_dec bcd_humi(.bin(distance_cm[11:0]),  .bcd(distance_cm_bcd));

    fnd_cntr fnd (.clk(clk), .reset_p(reset_p), 
        .value(distance_cm_bcd), .com(com), .seg_7(seg_7));
endmodule

module led_pwm_top(
    input clk, reset_p,
    output pwm, led_r, led_g, led_b);
    
    reg [31:0] clk_div;
    always @(posedge clk)clk_div = clk_div + 1;
    
    pwm_100step pwm_inst(.clk(clk), .reset_p(reset_p), .duty(clk_div[25:19]), .pwm(pwm));
    
    pwm_Nstep_freq #(.duty_step(77)) pwm_r(.clk(clk), .reset_p(reset_p), .duty(clk_div[28:23]), .pwm(led_r));
    pwm_Nstep_freq #(.duty_step(93)) pwm_g(.clk(clk), .reset_p(reset_p), .duty(clk_div[27:22]), .pwm(led_g));
    pwm_Nstep_freq #(.duty_step(103)) pwm_b(.clk(clk), .reset_p(reset_p), .duty(clk_div[26:21]), .pwm(led_b));

endmodule

module dc_motor_pwm_top(
    input clk, reset_p,
    output motor_pwm,
    output [3:0] com,
    output [7:0] seg_7);
    
    reg [31:0] clk_div;
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)clk_div = 0;
        else clk_div = clk_div + 1;
    end
    
    wire clk_div_26_nedge;
    edge_detector_n ed(
        .clk(clk), .reset_p(reset_p), .cp(clk_div[26]),
        .n_edge(clk_div_26_nedge));
    
    reg [6:0] duty;    
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)duty = 20;
        else if(clk_div_26_nedge)begin
            if(duty >= 50)duty = 20;
            else duty = duty + 1;
        end
    end
    
    pwm_Nstep_freq #(
        .duty_step(100), 
        .pwm_freq(100)) 
    pwm_motor(
        .clk(clk), 
        .reset_p(reset_p), 
        .duty(duty), 
        .pwm(motor_pwm));
        
    wire [15:0] duty_bcd;
    bin_to_dec bcd_humi(.bin({6'b0, duty}),  .bcd(duty_bcd));

    fnd_cntr fnd (.clk(clk), .reset_p(reset_p), 
        .value(duty_bcd), .com(com), .seg_7(seg_7));


endmodule

module sv_motor_pwm_top_PSH(
    input clk,            // �ý��� Ŭ��
    input reset_p,        // ���� ��ȣ (Ȱ�� ����)
    input [2:0] btn,
    output sv_pwm,        // ���� ���� ����� PWM ���
    output [3:0] com,    // 7���׸�Ʈ ���÷����� ���� ��
    output [7:0] seg_7   // 7���׸�Ʈ ���÷����� ���׸�Ʈ ��
);

//    reg [31:0] clk_div;
//    always @(posedge clk)clk_div = clk_div + 1;


//    edge_detector_n ed1(
//        .clk(clk), .reset_p(reset_p), 
//        .cp(btn_0), .n_edge(clk_div_btn0_nedge) );

//    edge_detector_n ed2(
//        .clk(clk), .reset_p(reset_p), 
//        .cp(btn_1), .n_edge(clk_div_btn1_nedge) );

//   edge_detector_n ed3(
//        .clk(clk), .reset_p(reset_p), 
//        .cp(btn_2), .n_edge(clk_div_btn2_nedge) );

    reg [5:0] duty;
    
    button_cntr btn0(.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_0));
    button_cntr btn1(.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(btn_1));
    button_cntr btn2(.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(btn_2));
    
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) duty = 12;
        else if(btn_0)duty = 12;
        else if(btn_1)duty = 32;
        else if(btn_2)duty = 48;
    end

    // 100Mhz / 400 / 50 = 500hz => 1/500 => 2ms
    pwm_Nstep_freq #(
        .duty_step(400),
        .pwm_freq(50))
    pwm_motor(
        .clk(clk),
        .reset_p(reset_p),
        .duty(duty),
        .pwm(sv_pwm));

    wire [15:0] duty_bcd;
    bin_to_dec bcd_distance(.bin({6'b0, duty}), .bcd(duty_bcd));

    fnd_cntr fnd(.clk(clk), .reset_p(reset_p),
        .value(duty_bcd), .com(com), .seg_7(seg_7));
endmodule

module surbo_motor_LHS(
    input clk, reset_p,
    input [2:0] btn,
    output [3:0] com,
    output [7:0] seg_7,
    output surbo_pwm
);

    wire btn_0, btn_1, btn_2;
    button_cntr btn0(.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_0));
    button_cntr btn1(.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(btn_1));
    button_cntr btn2(.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(btn_2));

    reg [31:0] clk_div;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p)
            clk_div = 0;
        else
            clk_div = clk_div + 1;
    end

    wire clk_div_24_nedge;

    edge_detector_n ed(
        .clk(clk),
        .reset_p(reset_p),
        .cp(clk_div[23]),
        .n_edge(clk_div_24_nedge)
    );

    reg [6:0] duty;       // duty ���������� ũ�⸦ 8��Ʈ�� ����
    reg down_up;        // ���� ��� ���� �÷��� (0: ����, 1: ����)
    reg [6:0] duty_min, duty_max;
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            duty = 12;       // �ʱ�ȭ 1ms (5% ��Ƽ ����Ŭ)
            down_up = 0;  // �ʱ� ���� ���� 
            duty_min = 12;
            duty_max = 50;
        end
        else if (clk_div_24_nedge) begin // 20ms �ֱ�
            if (!down_up) begin
                if (duty < duty_max)  // 2ms (10%)�� �������� �ʾҴٸ� ����
                    duty = duty + 1;
                else
                    down_up = 1;  // 2ms�� �����ϸ� ������ ���ҷ� ����
            end
            else begin
                if (duty > duty_min)  // 1ms (5%)�� �������� �ʾҴٸ� ����
                    duty = duty - 1;
                else
                    down_up = 0;  // 1ms�� �����ϸ� ������ ������ ����
            end
        end
        else if(btn_0)down_up = ~down_up;
        else if(btn_1)duty_min = duty;
        else if(btn_2)duty_max = duty;
    end

    pwm_Nstep_freq #(
        .duty_step(400),  // 100�ܰ�� ����
        .pwm_freq(50)     // PWM ���ļ� 50Hz
    ) pwm_motor(
        .clk(clk),
        .reset_p(reset_p),
        .duty(duty),
        .pwm(surbo_pwm)
    );

    wire [15:0] duty_bcd;

    bin_to_dec bcd_surbo(
        .bin({8'b0, duty}),
        .bcd(duty_bcd)
    );

    // fnd_cntr ��� �ν��Ͻ�
    fnd_cntr fnd_cntr_inst(
        .clk(clk),
        .reset_p(reset_p),
        .value(duty_bcd),
        .com(com),
        .seg_7(seg_7)
    );

endmodule

module adc_ch6_top(
    input clk, reset_p,
    input vauxp6, vauxn6,
    output [3:0] com,
    output [7:0] seg_7,
    output led_pwm);
    
    wire [4:0] channel_out;
    wire [15:0] do_out;
    wire eoc_out;
    xadc_wiz_0 adc_6
          (
          .daddr_in({2'b0, channel_out}),            // Address bus for the dynamic reconfiguration port
          .dclk_in(clk),             // Clock input for the dynamic reconfiguration port
          .den_in(eoc_out),              // Enable Signal for the dynamic reconfiguration port
          .reset_in(reset_p),            // Reset signal for the System Monitor control logic
          .vauxp6(vauxp6),              // Auxiliary channel 6
          .vauxn6(vauxn6),
          .channel_out(channel_out),         // Channel Selection Outputs
          .do_out(do_out),              // Output data bus for dynamic reconfiguration port
          .eoc_out(eoc_out)             // End of Conversion Signal
          );
    
    pwm_Nstep_freq #(
        .duty_step(256),  
        .pwm_freq(10000)     
    ) pwm_backlight(
        .clk(clk),
        .reset_p(reset_p),
        .duty(do_out[15:8]),
        .pwm(led_pwm)
    );
    
    
    
    
    wire [15:0] adc_value;

    bin_to_dec bcd_adc(.bin({2'b0, do_out[15:6]}), .bcd(adc_value));
    fnd_cntr fnd_cntr_inst(.clk(clk), .reset_p(reset_p),
        .value(adc_value), .com(com), .seg_7(seg_7));
endmodule

module adc_sequence2_top(
    input clk, reset_p,
    input vauxp6, vauxn6, vauxp15, vauxn15,
    output led_r, led_g,
    output [3:0] com,
    output [7:0] seg_7);

    wire [4:0] channel_out;
    wire [15:0] do_out;
    wire eoc_out;
    xadc_wiz_1 adc_seq2
          (
          .daddr_in({2'b0, channel_out}),            // Address bus for the dynamic reconfiguration port
          .dclk_in(clk),             // Clock input for the dynamic reconfiguration port
          .den_in(eoc_out),              // Enable Signal for the dynamic reconfiguration port
          .reset_in(reset_p),            // Reset signal for the System Monitor control logic
          .vauxp6(vauxp6),              // Auxiliary channel 6
          .vauxn6(vauxn6),
          .vauxp15(vauxp15),              // Auxiliary channel 6
          .vauxn15(vauxn15),
          .channel_out(channel_out),         // Channel Selection Outputs
          .do_out(do_out),              // Output data bus for dynamic reconfiguration port
          .eoc_out(eoc_out)             // End of Conversion Signal
          );
    
    wire eoc_out_pedge;      
    edge_detector_n ed(
        .clk(clk),
        .reset_p(reset_p),
        .cp(eoc_out),
        .p_edge(eoc_out_pedge)
    );
    
    reg [11:0] adc_value_x, adc_value_y;
    always @(posedge clk or posedge reset_p)begin
        if(reset_p) begin
            adc_value_x = 0;
            adc_value_y = 0;
        end
        else if(eoc_out_pedge)begin
            case(channel_out[3:0])
                6: adc_value_x = do_out[15:4];
                15: adc_value_y = do_out[15:4];
            endcase
        end
    end
    
    pwm_Nstep_freq #(
        .duty_step(256),  
        .pwm_freq(10000)     
    ) pwm_red(
        .clk(clk),
        .reset_p(reset_p),
        .duty(adc_value_x[11:4]),
        .pwm(led_r)
    );
    pwm_Nstep_freq #(
        .duty_step(256),  
        .pwm_freq(10000)     
    ) pwm_green(
        .clk(clk),
        .reset_p(reset_p),
        .duty(adc_value_y[11:4]),
        .pwm(led_g)
    );
    
    wire [15:0] bcd_x, bcd_y, value;
    bin_to_dec bcd_adc_x(.bin({6'b0, adc_value_x[11:6]}), .bcd(bcd_x));
    bin_to_dec bcd_adc_y(.bin({6'b0, adc_value_y[11:6]}), .bcd(bcd_y));
    
    assign value = {bcd_x[7:0], bcd_y[7:0]};
    fnd_cntr fnd_cntr_inst(.clk(clk), .reset_p(reset_p),
        .value(value), .com(com), .seg_7(seg_7));

endmodule

module i2c_master_top(
    input clk, reset_p,
    input [1:0] btn,
    output scl, sda,
    output [15:0] led_debug
);
    reg [7:0] data;
    reg comm_go;
    
    wire [1:0] btn_pedge;
    button_cntr btn0(.clk(clk), .reset_p(reset_p), .btn(btn[0]), 
        .btn_pedge(btn_pedge[0]));
    button_cntr btn1(.clk(clk), .reset_p(reset_p), .btn(btn[1]), 
        .btn_pedge(btn_pedge[1]));
        
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            data = 0;
            comm_go = 0;
        end
        else begin
            if(btn_pedge[0])begin
                data = 8'b0000_0000;
                comm_go = 1;
            end
            else if(btn_pedge[1])begin
                data = 8'b0000_1000;
                comm_go = 1;
            end
            else comm_go = 0;
        end
    end
    
    I2C_master master(.clk(clk), .reset_p(reset_p),
        .addr(7'h27),
        .rd_wr(0),
        .data(data),
        .comm_go(comm_go),
        .scl(scl), .sda(sda),
        .led(led));

endmodule

module i2c_txtlcd_top(
    input clk, reset_p,
    input [3:0] btn,
    output scl, sda,
    output [15:0] led_debug);

    parameter IDLE              = 6'b00_0001;
    parameter INIT              = 6'b00_0010;
    parameter SEND_DATA         = 6'b00_0100;
    parameter SEND_COMMAND      = 6'b00_1000;
    parameter SEND_STRING       = 6'b01_0000;
    
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
    
    wire [3:0] btn_pedge;
    button_cntr btn0(.clk(clk), .reset_p(reset_p), .btn(btn[0]), 
        .btn_pedge(btn_pedge[0]));
    button_cntr btn1(.clk(clk), .reset_p(reset_p), .btn(btn[1]), 
        .btn_pedge(btn_pedge[1]));
    button_cntr btn2(.clk(clk), .reset_p(reset_p), .btn(btn[2]), 
        .btn_pedge(btn_pedge[2]));    
    button_cntr btn3(.clk(clk), .reset_p(reset_p), .btn(btn[3]), 
        .btn_pedge(btn_pedge[3]));
    
    reg [7:0] send_buffer;
    reg rs, send;
    wire busy;
    i2c_lcd_send_byte txtlcd(.clk(clk), .reset_p(reset_p),
        .addr(7'h27),
        .send_buffer(send_buffer),
        .rs(rs), .send(send),
        .scl(scl), .sda(sda),
        .busy(busy),
        .led(led_debug));
        
    reg [5:0] state, next_state;
    always @(negedge clk or posedge reset_p)begin
        if(reset_p)state = IDLE;
        else state = next_state;
    end
    reg init_flag;
    reg [3:0] cnt_data;
    reg [8*5-1:0] hello;
    reg [3:0] cnt_string;
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            next_state = IDLE;
            init_flag = 0;
            cnt_data = 0;
            rs = 0;
            hello = "HELLO";
            cnt_string = 0;
        end
        else begin
            case(state)
                IDLE:begin
                    if(init_flag)begin
                        if(btn_pedge[0])next_state = SEND_DATA;
                        if(btn_pedge[1])next_state = SEND_COMMAND;
                        if(btn_pedge[2])next_state = SEND_STRING;
                    end
                    else begin
                        if(count_usec <= 22'd80_000)begin
                            count_usec_e = 1;
                        end
                        else begin
                            next_state = INIT;
                            count_usec_e = 0;
                        end
                    end
                end
                INIT:begin
                    if(busy)begin
                        send = 0;
                        if(cnt_data >= 6)begin
                            next_state = IDLE;
                            init_flag = 1;
                            cnt_data = 0;
                        end
                    end
                    else if(!send)begin
                        case(cnt_data)
                            0:send_buffer = 8'h33;
                            1:send_buffer = 8'h32;
                            2:send_buffer = 8'h28;
                            3:send_buffer = 8'h0f;
                            4:send_buffer = 8'h01;
                            5:send_buffer = 8'h06;
                        endcase
                        rs = 0;
                        send = 1;
                        cnt_data = cnt_data + 1;
                    end
                    
                end
                SEND_DATA:begin
                    if(busy)begin
                        next_state = IDLE;
                        send = 0;
                        if(cnt_data >= 9)cnt_data = 0;
                        else cnt_data = cnt_data + 1;
                    end
                    else begin
                        send_buffer = "0" + cnt_data;
                        rs = 1;
                        send = 1;
                    end
                end
                SEND_COMMAND:begin
                    if(busy)begin
                        next_state = IDLE;
                        send = 0;
                    end
                    else begin
                        send_buffer = 8'h18;
                        rs = 0;
                        send = 1;
                    end
                end
                SEND_STRING:begin
                    if(busy)begin
                        send = 0;
                        if(cnt_string >= 5)begin
                            next_state = IDLE;
                            cnt_string = 0;
                        end
                    end
                    else if(!send)begin
                        case(cnt_string)
                            0:send_buffer = hello[39:32];
                            1:send_buffer = hello[31:24];
                            2:send_buffer = hello[23:16];
                            3:send_buffer = hello[15:8];
                            4:send_buffer = hello[7:0];
                        endcase
                        rs = 1;
                        send = 1;
                        cnt_string = cnt_string + 1;
                    end
                end
            endcase
        end
    end

endmodule




















