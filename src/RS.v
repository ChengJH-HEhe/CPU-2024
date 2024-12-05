`include "const.v"

module RS #(
  parameter RS_SIZE_BIT = `RS_WIDTH_BIT
) (
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
  input  wire					        rdy_in,			// ready signal, pause cpu when low

  // from Decoder

  // from ROB
  
  // from LSB

  // to Decoder

  // to ALU

  // 
);

  localparam RS_SIZE = 1 << RS_SIZE_BIT;

endmodule