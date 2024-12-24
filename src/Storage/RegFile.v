`include "const.v"

module RegFile (
  input wire clk_in,  // system clock signal
  input wire rst_in,  // reset signal
  input wire rdy_in,  // ready signal, pause cpu when low
  // needed wire
  input wire clear_flag,


  // from decoder, issue ask dep-id or val
  input wire [4: 0] ask_reg_id1,
  input wire [4: 0] ask_reg_id2,
  output wire [31: 0] ret_val_id1,
  output wire [31: 0] ret_val_id2,
  output wire dep_rs1,
  output wire dep_rs2,
  output wire [`ROB_WIDTH_BIT - 1: 0] ret_ROB_id1,
  output wire [`ROB_WIDTH_BIT - 1: 0] ret_ROB_id2,

  // from ROB, issue update rd, value.
  input wire [4: 0] new_reg_id,
  input wire [`ROB_WIDTH_BIT - 1: 0] new_ROB_id,

  // from ROB, commit, write back register value.
  input wire [4: 0] write_reg_id,
  input wire [`ROB_WIDTH_BIT - 1: 0] write_ROB_id,
  input wire [31: 0] write_val,

  output wire [`ROB_WIDTH_BIT - 1 : 0] rs1_id,
  input wire rs1_ready,
  input wire [31 : 0] rs1_val,

  output wire [`ROB_WIDTH_BIT - 1 : 0] rs2_id,
  input wire rs2_ready,
  input wire [31 : 0] rs2_val
  // RS op1, op2, free dependency? 
  
);
  reg [31:0] regs[0:31];
  reg [`ROB_WIDTH_BIT-1:0] Qi[0:31];
  reg is_Qi[0:31];

  // ask ROB for dependency.(may be rs1_val if it's just calced)
  wire has_dep_id1 = is_Qi[ask_reg_id1] || new_reg_id && ask_reg_id1 == new_reg_id;
  wire has_dep_id2 = is_Qi[ask_reg_id2] || new_reg_id && ask_reg_id2 == new_reg_id;

  assign ret_ROB_id1 = ask_reg_id1 == new_reg_id ? new_ROB_id : Qi[ask_reg_id1];
  assign ret_ROB_id2 = ask_reg_id2 == new_reg_id ? new_ROB_id : Qi[ask_reg_id2];
  assign ret_val_id1 = has_dep_id1 ? rs1_val : regs[ask_reg_id1];
  assign ret_val_id2 = has_dep_id2 ? rs2_val : regs[ask_reg_id2];
  assign dep_rs1 = has_dep_id1 && !rs1_ready;
  assign dep_rs2 = has_dep_id2 && !rs2_ready;  

  assign rs1_id = ret_ROB_id1;
  assign rs2_id = ret_ROB_id2;

  always @(posedge clk_in) begin : MainBlock
    integer i;
    if(rst_in) begin
      for(i = 0; i < 32; i = i + 1) begin
        regs[i] <= 0;
        Qi[i] <= 0;
        is_Qi[i] <= 0;
      end
    end else if (!rdy_in) begin
    end else begin
      
      if(clear_flag) begin
        for(i = 0; i < 32; i = i + 1) begin
          Qi[i] <= 0;
          is_Qi[i] <= 0;
        end
      end else begin
        if(write_reg_id) begin
          regs[write_reg_id] <= write_val;
          if(write_reg_id != new_reg_id && Qi[write_reg_id] == write_ROB_id) begin
            is_Qi[write_reg_id] <= 0;
            Qi[write_reg_id] <= 0;
          end
          // for(i = 0; i < 32; i = i + 1) begin
          //   $write("%d\t", regs[i]);
          // end
          $display("");
        end
        if(new_reg_id) begin
          is_Qi[new_reg_id] <= 1;
          Qi[new_reg_id] <= new_ROB_id;
        end
      end

    end
  end
  

  
endmodule