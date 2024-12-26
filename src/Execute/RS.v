`include "const.v"

module RS #(
  parameter RS_SIZE_BIT = `RS_WIDTH_BIT,
  parameter RS_TYPE_BIT = `RS_TYPE
) (
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
  input  wire					        rdy_in,			// ready signal, pause cpu when low
  input  wire clear_flag, // clear all data in RS
  // receive from Decoder (ins_info)
  input wire inst_valid,
  input wire [`RS_TYPE - 1 : 0] ins_Type, // 0: NOP, 1: rs-ALU, 2: lsb-MEM, 3: rs-BRANCH
  
  input wire [31 : 0] ins_rs1,
  input wire [31 : 0] ins_rs2,
  input wire is_Qi,
  input wire is_Qj,
  input wire [4 : 0] Qi,
  input wire [4 : 0] Qj,
  input wire [31 : 0] Imm_in,
  input wire [31 : 0] Pc_in,
  input wire [4 : 0] ROB_id,

  output wire full,

  
  // to ALU
  output reg [6 : 0] alu_op ,
  output reg [31 : 0] Vi ,
  output reg [31 : 0] Vj ,
  output reg [31 : 0] imm,
  output reg [4 : 0] rd,
  output reg [31:0] pc,
  
  // from LSB calc ready direct update
  input wire lsb_ready,
  input wire [4:0]lsb_rob_id,
  input wire [31:0] lsb_val,
  // from ALU
  input wire  rs_ready,
  input wire [4:0] rs_ROB_id,
  input wire [31:0] rs_val

  // to Decoder
);

localparam RS_SIZE = 1 << RS_SIZE_BIT;

// private data
reg valid[0 : RS_SIZE - 1];
reg [`RS_TYPE - 1 : 0] Type[0 : RS_SIZE - 1]; // 0: NOP, 1: rs-ALU, 2: lsb-MEM, 3: rs-BRANCH

reg [31 : 0] rs1[0 : RS_SIZE - 1];
reg [31 : 0] rs2[0 : RS_SIZE - 1];
reg [31 : 0] Imm[0 : RS_SIZE - 1];
reg [4 : 0] Rd[0 : RS_SIZE - 1];
reg [31:0] Pc[0 : RS_SIZE - 1];
reg _is_Qi[0 : RS_SIZE - 1];
reg _is_Qj[0 : RS_SIZE - 1];
reg [4 : 0] _Qi[0 : RS_SIZE - 1];
reg [4 : 0] _Qj[0 : RS_SIZE - 1];

wire exec[0 : RS_SIZE - 1];
wire [RS_SIZE_BIT : 0] ready_add;
wire [RS_SIZE_BIT : 0] ready_del;
// generate executable
generate
  genvar gen_i;
  // find busy = 1, qi = 0, qj = 0, to execute
  for (gen_i = 0; gen_i < RS_SIZE; gen_i = gen_i + 1) begin: gen_exec
    assign exec[gen_i] = valid[gen_i] && !_is_Qi[gen_i] && !_is_Qj[gen_i];
  end 
endgenerate

assign ready_del = exec[0] == 1 ? 0 : exec[1] == 1 ? 1 : exec[2] == 1 ? 2 : exec[3] == 1 ? 3 : exec[4] == 1 ? 4 : exec[5] == 1 ? 5 : exec[6] == 1 ? 6 : exec[7] == 1 ? 7 : 8;
assign ready_add = valid[0] == 0 ? 0 : valid[1] == 0 ? 1 : valid[2] == 0 ? 2 : valid[3] == 0 ? 3 : valid[4] == 0 ? 4 : valid[5] == 0 ? 5 : valid[6] == 0 ? 6 : valid[7] == 0 ? 7 : 8;
assign full = ready_add == RS_SIZE;

integer i;

always @(posedge clk_in) begin
  if (rst_in || clear_flag) begin
    for (i = 0; i < RS_SIZE; i = i + 1) begin
      valid[i] <= 0;
      Type[i] <= 0;
      rs1[i] <= 0;
      Rd[i] <= 0;
      Pc[i] <= 0;
      rs2[i] <= 0;
      _is_Qi[i] <= 0;
      _is_Qj[i] <= 0;
      _Qi[i] <= 0;
      _Qj[i] <= 0;
    end
  end else if(rdy_in) begin
    if (ready_add < RS_SIZE && inst_valid) begin
      valid[ready_add] <= 1;
      Type[ready_add] <= ins_Type;
      _is_Qi[ready_add] <= (lsb_ready && lsb_rob_id == Qi) ? 0 : (rs_ready && rs_ROB_id == Qi) ? 0: is_Qi; // lsb_ready, rs_ready
      _is_Qj[ready_add] <= (lsb_ready && lsb_rob_id == Qj) ? 0 : (rs_ready && rs_ROB_id == Qj) ? 0: is_Qj;
      rs1[ready_add] <= (lsb_ready && lsb_rob_id == Qi) ? lsb_val : (rs_ready && rs_ROB_id == Qi) ? rs_val: ins_rs1;
      rs2[ready_add] <= (lsb_ready && lsb_rob_id == Qj) ? lsb_val : (rs_ready && rs_ROB_id == Qj) ? rs_val: ins_rs2;
      _Qi[ready_add] <= Qi;
      _Qj[ready_add] <= Qj;
      Imm[ready_add] <= Imm_in;
      Rd[ready_add] <= ROB_id;
      Pc[ready_add] <= Pc_in;
    end
    if (rs_ready) begin // result ok
      // delete correspondant dependency
      for (i = 0; i < RS_SIZE; i = i + 1) begin 
        if (_is_Qi[i] && _Qi[i] == rs_ROB_id) begin
          Vi[i] <= rs_val;
          _Qi[i] <= 0;
          _is_Qi[i] <= 0;
        end
        if (_is_Qj[i] &&_Qj[i] == rs_ROB_id) begin
          Vj[i] <= rs_val;
          _Qj[i] <= 0;
          _is_Qj[i] <= 0;
        end
      end 
    end
    if (lsb_ready) begin
      for (i = 0; i < RS_SIZE; i = i + 1) begin 
        if (_is_Qi[i] && _Qi[i] == lsb_rob_id) begin
          Vi[i] <= lsb_val;
          _Qi[i] <= 0;
          _is_Qi[i] <= 0;
        end
        if (_is_Qj[i] && _Qj[i] == lsb_rob_id) begin
          Vj[i] <= lsb_val;
          _Qj[i] <= 0;
          _is_Qj[i] <= 0;
        end
      end
    end
    // execute.
    if(ready_del < RS_SIZE) begin
      alu_op <= Type[ready_del];
      Vi <= rs1[ready_del];
      Vj <= rs2[ready_del];
      imm <= Imm[ready_del];
      pc <= Pc[ready_del];
      rd <= Rd[ready_del];
      valid[ready_del] <= 0;
    end else begin
      alu_op <= 0;
      Vi <= 0;
      Vj <= 0;
      imm <= 0;
      pc <= 0;
      rd <= 0;
    end
  end
end
endmodule