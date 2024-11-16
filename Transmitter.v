`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/10 22:01:04
// Design Name: 
// Module Name: Transmitter
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


module Transmitter(
    input clk,
    input [7:0] sw,
    input transmit,
    input reset_p,
    output reg Tx);
    
    // initial variables
    
    reg [3:0] bit_counter; // counter to count the 10 bits
    reg [13:0] baudrate_counter; // 10,415, counter-clock(100 Mhz) / BR(9600)
    reg [9:0] shiftright_register; // 10 bits that will be serially transmitted through UART to the basys3
    reg state, next_state; // idle mode and transmitting mode
    reg shift; //shift signal to start shifting the bits in the UART
    reg load; // load signal to start loading the data into the shiftright register, and add start and stop bits
    reg clear; // reset the bit_counter for UART transmission
    
    // UART trans
    
    always @(posedge clk or posedge reset_p)begin
        if(reset_p)begin
            state = 0; // satae is idle
            bit_counter = 0; // counter for bit transmission is reset to 0
            baudrate_counter = 0;
        end
        else begin
            baudrate_counter = baudrate_counter + 1;
            if(baudrate_counter == 10415)begin
                state = next_state; // state changes from idle to tansmitting
                baudrate_counter = 0; //resetting counter
            end
            if(load)begin // if load is asserted
                shiftright_register = {1'b1, sw, 1'b0}; // the data is loaded into the register, 10-bits
            end
            if(clear)begin // if clear is asserted
                bit_counter = 0;
            end
            if(shift)begin // if shift signal is asserted
                shiftright_register = shiftright_register >> 1; // start shifting the data and transmitting bit by bit
            end
            bit_counter = bit_counter + 1;
       end
   end
   
   // mealy machine, state machine
   always @(posedge clk or posedge reset_p) begin 
        if(reset_p)begin
            load = 0;  //setting load equal to 0
            shift = 0; // initially 0
            clear = 0; // initially 0
            Tx = 1;  // when set to 1. 
        end else begin
        case(state) // idle state
        0: begin
            if(transmit) begin // transmmit button is pressed
                next_state = 1; // it moves / switches to transmission state
                load = 1; // start loading the bits
                shift = 0; //no shift at this point
                clear = 0; // to avoid any clearing of any counter
            end
            else begin // if transmit button is not asserted / pressed
                next_state = 0; // always at the idle mode
                Tx = 1; // no transmitted
            end
        end
       
        1: begin // transmitted
            if(bit_counter == 10)begin
                next_state = 0; // it should switch from transmission mode to idle modes
                clear = 1; // clear all the counters
            end
            else begin
                next_state = 1; // stay in the transmit state
                Tx = shiftright_register[0];
                shift = 1; // continue shifting the data, new bit arrives at the RNB
            end
         end
            default: next_state = 0;
       endcase
   end
end
   
endmodule