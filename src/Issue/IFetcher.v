`include "const.v"

module IFectcher (
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
    input  wire					rdy_in,			// ready signal, pause cpu when low

    // icache
    input wire [31 : 0] input_ins,
    input wire input_ins_ready,
    output reg [31 : 0] pc,
    output reg is_fetching,

    // decoder ok to receive?

    // Decoder (TODO add branch-predictor)
    output reg [31 : 0] output_ins,
    output reg output_ins_ready,
    output reg [31 : 0] output_pc
    
    // b-predictor

    // 

);

endmodule