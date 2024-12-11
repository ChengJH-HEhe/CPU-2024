`include "const.v"

// load or store > insFetch.

module MemCtrl (
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
    input  wire					rdy_in,			// ready signal, pause cpu when low

  // to load,store
  output reg lsb_val_ready, // mem_val valid
  output reg [31 : 0] lsb_val,

  input wire lsb_need, // store or load reg valid
  input wire [31 : 0] addr,
  input wire [31 : 0] data,
  input wire load_or_store,
  input wire [6 : 0] op,
  
  // with ram
  output reg ram_type,
  output reg [31 : 0] addr_ram,
  output reg [31 : 0] data_ram,



  // from/to ICache
  input wire iCache_need,
  input wire [31 : 0] ins_addr,
  output reg ins_ready,
  output reg [31 : 0] ins

);

reg[1:0] state;



endmodule