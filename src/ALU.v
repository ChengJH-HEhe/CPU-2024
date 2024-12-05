`include "const.v"

module ALU (
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
  input  wire					        rdy_in,			// ready signal, pause cpu when low

  //
);
  always @(posedge clk_in) begin
    if (rst_in) begin
      // clear
    end else if (!rdy_in) begin
      // do nothing
    end else begin
      // work
    end
  end
endmodule