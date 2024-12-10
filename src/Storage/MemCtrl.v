`include "const.v"

module MemCtrl (
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
    input  wire					rdy_in,			// ready signal, pause cpu when low

    // 
    // from & to memoryController
  output reg mem_ready, // mem_val valid
  output reg [31 : 0] mem_val,

  input wire full_mem, // store or load reg valid
  input wire [31 : 0] addr,
  input wire [31 : 0] data,
  input wire load_or_store,
  input wire [6 : 0] op

    // 

);

endmodule