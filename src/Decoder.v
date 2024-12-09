`include "const.v"

module Decoder (
  input wire clk_in,  // system clock signal
  input wire rst_in,  // reset signal
  input wire rdy_in,  // ready signal, pause cpu when low
  // needed wire

  // ins input
  input wire [31 : 0]ins,
  input wire ins_ready,

  // output to ROB

  // output to RS

  // output to LSB
  


);

endmodule