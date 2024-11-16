`timescale 1ns / 1ps

// UART 송신기
module uart_tx(
    input clk,             // FPGA 클럭
    input reset,           // 리셋 신호
    input [7:0] data_in,   // 전송할 데이터
    input send,            // 전송 트리거
    output reg tx,         // UART 전송 핀
    output reg busy        // 전송 중 상태
);
    parameter CLK_FREQ = 100_000_000; // 클럭 주파수 (100MHz)
    parameter BAUD_RATE = 9600;       // UART 전송 속도
    parameter BIT_PERIOD = CLK_FREQ / BAUD_RATE; // 각 비트의 전송 주기

    reg [3:0] bit_index;    // 현재 전송 중인 비트의 인덱스
    reg [15:0] baud_count;  // 비트 전송을 위한 카운터
    reg [9:0] tx_shift_reg; // 데이터와 스타트, 스톱 비트를 포함한 10비트 레지스터

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx <= 1;         // 기본 상태
            busy <= 0;       // 현재 전송 중이 아님
            baud_count <= 0;
            bit_index <= 0;
            tx_shift_reg <= 10'b1111111111; // 기본 상태
        end else if (send && !busy) begin
            tx_shift_reg <= {1'b1, data_in, 1'b0}; // 데이터와 스타트 비트, 스톱 비트
            busy <= 1;
            bit_index <= 0; // 비트 인덱스 초기화
        end else if (busy) begin
            if (baud_count < BIT_PERIOD - 1) begin
                baud_count <= baud_count + 1;
            end else begin
                baud_count <= 0;
                tx <= tx_shift_reg[0];
                tx_shift_reg <= {1'b1, tx_shift_reg[9:1]}; // 비트 시프트
                if (bit_index < 9) begin
                    bit_index <= bit_index + 1;
                end else begin
                    busy <= 0; // 전송 완료
                    bit_index <= 0;
                end
            end
        end
    end
endmodule

//----------------------------------------------------------------------------------------------------------------------------------------

module uart_rx (
    input clk, reset_p,
    input rx,                 // UART 수신 핀 (HC-06의 TX 핀에 연결)
    output reg [7:0] data_out, // 수신된 데이터
    output reg received       // 데이터 수신 완료 신호
);

    parameter CLKS_PER_BIT = 10417; // 100MHz / 9600 baud rate
    parameter CLKS_PER_HALF_BIT = CLKS_PER_BIT / 2;

    reg [3:0] state;
    reg [15:0] clock_count;
    reg [2:0] bit_index;
    reg [7:0] rx_data;

    parameter IDLE = 4'b0000;
    parameter START_BIT = 4'b0001;
    parameter DATA_BITS = 4'b0010;
    parameter STOP_BIT = 4'b0011;
    parameter CLEANUP = 4'b0100;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            state <= IDLE;
            received <= 1'b0;
            data_out <= 8'h00;
            clock_count <= 0;
            bit_index <= 0;
        end
            else begin
                case (state)
                    IDLE: begin
                        received <= 1'b0;
                        clock_count <= 0;
                        bit_index <= 0;
                        
                        if (rx == 1'b0) begin
                            state <= START_BIT;
                        end
                    end
                    START_BIT: begin
                        if (clock_count == CLKS_PER_HALF_BIT) begin
                            if (rx == 1'b0) begin
                                clock_count <= 0;
                                state <= DATA_BITS;
                            end
                                else begin
                                    state <= IDLE;
                                end
                        end
                            else begin
                                clock_count <= clock_count + 1;
                            end
                    end
                    DATA_BITS: begin
                        if (clock_count < CLKS_PER_BIT - 1) begin
                            clock_count <= clock_count + 1;
                        end
                            else begin
                                clock_count <= 0;
                                rx_data[bit_index] <= rx;
                                if (bit_index < 7) begin
                                    bit_index <= bit_index + 1;
                                end
                                    else begin
                                        bit_index <= 0;
                                        state <= STOP_BIT;
                                    end
                            end
                    end
                    STOP_BIT: begin
                        if (clock_count < CLKS_PER_BIT - 1) begin
                            clock_count <= clock_count + 1;
                        end
                            else begin
                                received <= 1'b1;
                                data_out <= rx_data;
                                state <= CLEANUP;
                            end
                    end
                    CLEANUP: begin
                        state <= IDLE;
                        received <= 1'b0;
                    end
                    default: state <= IDLE;
                endcase
            end
    end
endmodule

// 최상위 TOP Module-----------------------------------------------------------------------------------------------------------------------
module SOC_check_top(
    input clk,              // 100 MHz 클럭
    input reset_p,        // switch 리셋 신호
    input [4:0] btn,        // 4개의 버튼 입력
    output tx,              // UART 송신 핀
    input rx,               // UART 수신 핀
    output [3:0] com,       // 7-세그먼트 공통 캐소드 선택
    output [7:0] seg_7,     // 7-세그먼트 세그먼트 제어
    output reg [15:0] led   // LED 출력
);

    // 버튼 엣지 검출 신호
    wire btn_up, btn_left, btn_right, btn_down;     // 버튼 엣지 검출 신호
    wire [15:0] value;                              // 표시할 16비트 값
    reg [3:0] digit [0:3];                          // 4개의 4비트 자릿수 배열
    reg [1:0] sel_digit;                            // 현재 선택된 자릿수
    // FND 값을 저장할 레지스터
    reg [15:0] save_fnd_value;

    // 버튼 엣지 검출 모듈 인스턴스화
    button_cntr btn0_counter(.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_set));
    button_cntr btn1_counter(.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(btn_up));
    button_cntr btn2_counter(.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(btn_left));
    button_cntr btn3_counter(.clk(clk), .reset_p(reset_p), .btn(btn[3]), .btn_pedge(btn_right));
    button_cntr btn4_counter(.clk(clk), .reset_p(reset_p), .btn(btn[4]), .btn_pedge(btn_down));

    // 버튼을 눌러서 숫자를 조작하는 로직
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            digit[0] <= 4'd0;
            digit[1] <= 4'd0;
            digit[2] <= 4'd0;
            digit[3] <= 4'd0;
            sel_digit <= 2'b00;
        end
            else begin
                // 자릿수 선택 및 값 변경 로직
                if (btn_right) sel_digit <= (sel_digit == 2'b00) ? 2'b11 : sel_digit - 1;
                if (btn_left) sel_digit <= (sel_digit == 2'b11) ? 2'b00 : sel_digit + 1;
    
                if (btn_up && digit[sel_digit] < 4'd9) digit[sel_digit] <= digit[sel_digit] + 1;
                if (btn_down && digit[sel_digit] > 4'd0) digit[sel_digit] <= digit[sel_digit] - 1;
            end
    end

    // 7-세그먼트 표시를 위한 값 설정
    assign value = {digit[3], digit[2], digit[1], digit[0]};

    // 7-세그먼트 컨트롤러 인스턴스화
    fnd_cntr fnd_controller(
        .clk(clk),
        .reset_p(reset_p),
        .value(value),
        .com(com),
        .seg_7(seg_7)
    );

    // 통신 관련 파라미터 및 신호 정의
    parameter CLK_FREQ = 100_000_000;      // 클럭 주파수 (100MHz)
    parameter BAUD_RATE = 9600;            // UART의 전송 속도 (9600bps)
    parameter CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // 송신 신호
    reg [7:0] data_to_send;   // 전송할 데이터
    reg send;                 // 데이터 전송 트리거
    wire busy;                // 전송 중 상태

    // 수신 신호
    wire [7:0] received_data;  // 수신 데이터
    wire received_flag;        // 데이터 수신 완료 신호
    reg send_flag;
    wire busy_flag;

    // 상태 정의
    localparam IDLE = 3'b000;          // 대기 상태
    localparam SEND_DIGIT = 3'b001;    // 숫자 송신 상태
    localparam WAIT_BUSY = 3'b010;     // 송신 완료 대기 상태

    // 상태 머신 및 UART 송신 로직
    reg [2:0] state;                    // 상태 머신 상태
    reg [1:0] digit_index;              // 현재 자릿수 인덱스
    reg btn_set_prev;                   // 이전 btn_set 상태

    // 송신 모듈 인스턴스화
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .reset(reset_p),
        .data_in(data_to_send),
        .send(send),
        .tx(tx),
        .busy(busy)
    );

    // 수신 모듈 인스턴스화
    uart_rx uart_receiver (
        .clk(clk),
        .reset_p(reset_p),
        .rx(rx),
        .data_out(received_data),
        .received(received_flag)
    );
    
    // 송신 로직
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            save_fnd_value <= 16'h0000;   // FND 값 초기화
            data_to_send <= 8'h00;
            send <= 1'b0;
            state <= IDLE;
            digit_index <= 2'd3; // 역순으로 시작하기 위해 3으로 초기화
            btn_set_prev <= 1'b0;
        end
            else begin
                btn_set_prev <= btn_set;
                case (state)
                    IDLE: begin
                        if (btn_set && !btn_set_prev) begin  // btn_set의 상승 엣지 감지
                            save_fnd_value <= value;        // 현재 FND 값을 저장
                        end
                        if (received_flag && received_data == "Q") begin
                            digit_index <= 2'd3;            // 전송할 자릿수를 초기화
                            state <= SEND_DIGIT;            // 송신 시작
                        end
                    end
                    SEND_DIGIT: begin
                        if (!busy) begin
                            case (digit_index)
                                2'd3: data_to_send <= save_fnd_value[15:12] + 8'h30; // 가장 상위 자릿수
                                2'd2: data_to_send <= save_fnd_value[11:8] + 8'h30;
                                2'd1: data_to_send <= save_fnd_value[7:4] + 8'h30;
                                2'd0: data_to_send <= save_fnd_value[3:0] + 8'h30; // 가장 하위 자릿수
                            endcase
                            send <= 1'b1;
                            state <= WAIT_BUSY;
                        end
                    end
                    WAIT_BUSY: begin
                        if (!busy) begin
                            send <= 1'b0;
                            if (digit_index == 2'd0) begin  // 모든 자릿수 전송 완료
                                state <= IDLE;
                            end
                                else begin
                                    digit_index <= digit_index - 1'b1; // 다음 자릿수로 이동
                                    state <= SEND_DIGIT;
                                end
                        end
                    end
                    default: state <= IDLE;
                endcase
            end
    end

    // 수신 및 LED 제어 로직 (수정하지 않음)
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            led <= 16'h0000;
            send_flag <= 1'b0;
        end
            else begin
                if (received_flag) begin
                    case (received_data)
                //필요한 부분만 주석을 풀어서 사용하세요.
                //학생--------------------------------------------------------------
//                      8'h30: led <= 16'h0000;  // ASCII '0'이면 모든 LED를 끔
//                      8'h31: led <= 16'hFFFF;  // ASCII '1'이면 모든 LED를 켬
                //------------------------------------------------------------------

                //선생님-------------------------------------------------------------
                    8'h30: led <= 16'h0000;  // ASCII '0'이면 모든 LED를 끔
                    8'h31: led[0] <= 1'b1;   // ASCII '1'이면 LED 1번만 켬
                    8'h32: led[1] <= 1'b1;   // ASCII '2'이면 LED 2번만 켬
                    8'h33: led[2] <= 1'b1;   // ASCII '3'이면 LED 2번만 켬
                    8'h34: led[3] <= 1'b1;   // ASCII '4'이면 LED 2번만 켬
                    8'h35: led[4] <= 1'b1;   // ASCII '5'이면 LED 2번만 켬
                    8'h36: led[5] <= 1'b1;   // ASCII '6'이면 LED 2번만 켬
                    8'h37: led[6] <= 1'b1;   // ASCII '7'이면 LED 2번만 켬
                    8'h38: led[7] <= 1'b1;   // ASCII '8'이면 LED 2번만 켬
                    8'h39: led[8] <= 1'b1;   // ASCII '9'이면 LED 2번만 켬

                    8'h41: led[0] <= 1'b0;   // ASCII 'A'이면 LED 1번만 끔 
                    8'h42: led[1] <= 1'b0;   // ASCII 'B'이면 LED 2번만 끔
                    8'h43: led[2] <= 1'b0;   // ASCII 'C'이면 LED 3번만 끔
                    8'h44: led[3] <= 1'b0;   // ASCII 'D'이면 LED 4번만 끔
                    8'h45: led[4] <= 1'b0;   // ASCII 'E'이면 LED 5번만 끔
                    8'h46: led[5] <= 1'b0;   // ASCII 'F'이면 LED 6번만 끔
                    8'h47: led[6] <= 1'b0;   // ASCII 'G'이면 LED 7번만 끔
                    8'h48: led[7] <= 1'b0;   // ASCII 'H'이면 LED 8번만 끔
                    8'h49: led[8] <= 1'b0;   // ASCII 'I'이면 LED 9번만 끔
                //-------------------------------------------------------------------
                            default: led <= led;     // 다른 값이면 LED 상태 유지
                    endcase
                    if (!busy) begin
                        send_flag <= 1'b1;
                    end
                end
                    else begin
                        send_flag <= 1'b0;
                    end
            end
    end

endmodule<html>
<head><title>416 Requested Range Not Satisfiable</title></head>
<body>
<center><h1>416 Requested Range Not Satisfiable</h1></center>
<hr><center>nginx</center>
</body>
</html>
