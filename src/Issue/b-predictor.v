`include "const.v"

// 8:2
module Bpredictor (
  input wire                 clk_in,			// system clock signal
  input wire                 rst_in,			// reset signal
  input wire					rdy_in,			// ready signal, pause cpu when low

  // insfetcher ask for prediction
  input wire [31 : 0] input_ins,
  input wire [31 : 0] input_pc,
  input wire Itype,
  output wire [31 : 0] predict_pc,

  // ROB update predictor
  input wire ROB_valid,
  input wire [31 : 0] ins_pc // pc[0] actual jump or not? 
);
  localparam RISC_B = 7'b1100011;
  reg [1:0] state[255:0];

wire predict_jump = ((Itype && input_ins[6:0] == RISC_B) || (!Itype && input_ins[15:14] == 2'b11 && input_ins[1:0] == 2'b01))? state[input_pc[8:1]][1] : 1'b0;
wire [31:0] immB = Itype ? {{20{input_ins[31]}}, input_ins[7], input_ins[30:25], input_ins[11:8], 1'b1}
                  : {{25{input_ins[12]}}, input_ins[6:5],input_ins[2],input_ins[11:10],input_ins[4:3],1'b1};
assign predict_pc = predict_jump? (input_pc + immB) : (input_pc + (Itype?32'h4:32'h2));

integer i;
always @(posedge clk_in) begin
  if(rst_in) begin
    for(i = 0; i < 256; i = i + 1) begin
      state[i] <= 2'b01;
    end
  end else if(~rdy_in) begin end else begin
    if(ROB_valid) 
      begin
        if(ins_pc[0]) begin
          if(state[ins_pc[8:1]] != 2'b11)
            state[ins_pc[8:1]] <=   state[ins_pc[8:1]] + 1;
        end else begin
          if(state[ins_pc[8:1]] != 2'b00)
            state[ins_pc[8:1]] <=   state[ins_pc[8:1]] - 1;
        end
    end
  end
end
endmodule