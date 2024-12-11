`include "const.v"
// circle 1 ins -> decode_imm.. -> 
module Decoder (
  input wire clk_in,  // system clock signal
  input wire rst_in,  // reset signal
  input wire rdy_in,  // ready signal, pause cpu when low
  // needed wire

  // ins input /from.to insFetcher
  input wire ins_ready,
  input wire [31 : 0]ins,
  input wire [31 : 0]pc,

  // output to insFetcher(stall)
  output wire IFetcher_stall,
  output reg [31: 0] IFetcher_new_addr,
  output reg IFetcher_clear,

  // input from ROB
  input wire ROB_ready,
  input wire [`ROB_WIDTH_BIT - 1: 0] ROB_del_Dep,
  // output to ROB
  output reg ROB_inst_valid,
  output reg ROB_inst_ready,
  output reg [31 : 0] ROB_ins_value,
  output reg [4 : 0] ROB_ins_rd,
  output reg [`ROB_TYPE - 1 : 0] ROB_ins_Type, // 0: NOP, 1: rs-ALU, 2: lsb-MEM, 3: rs-BRANCH
  output reg [31 : 0] ROB_ins_Addr,
  output reg [31 : 0] ROB_ins_jpAddr,

  // output to RS
  output reg RS_inst_valid,
  output reg [`RS_TYPE - 1 : 0] RS_ins_Type, // 0: NOP, 1: rs-ALU, 2: lsb-MEM, 3: rs-BRANCH
  output reg [31 : 0] RS_ins_value1,
  output reg [4 : 0] RS_ins_rs1,
  output reg [31 : 0] RS_ins_value2,
  output reg [4 : 0] RS_ins_rs2,
  output reg RS_is_Qi,
  output reg RS_is_Qj,
  output reg [4 : 0] RS_Qi,
  output reg [4 : 0] RS_Qj,

  // output to LSB
  output reg LSB_ins_valid,
  output reg [`LSB_TYPE - 1 : 0] LSB_ins_Type, // b,h,w / s,l 
  output reg [31 : 0] LSB_ins_value1,
  output reg [4 : 0] LSB_ins_rd, // rob_id,
  output reg [31 : 0] LSB_ins_value2,
  output reg LSB_is_Qi,
  output reg LSB_is_Qj,
  output reg [4 : 0] LSB_Qi,
  output reg [4 : 0] LSB_Qj,
  output reg [31 : 0] LSB_imm,

  // from/to REGF
  output reg [4: 0] ask_reg_id1,
  output reg [4: 0] ask_reg_id2,
  input wire [31: 0] REGF_ret_val_id1,
  input wire [31: 0] REGF_ret_val_id2,
  input wire REGF_dep_rs1,
  input wire REGF_dep_rs2,
  input wire [`ROB_WIDTH_BIT - 1: 0] REGF_ret_ROB_id1,
  input wire [`ROB_WIDTH_BIT - 1: 0] REGF_ret_ROB_id2
);

// wire decode input inst immediately
wire [6:0] opcode = ins[6:0];


wire [2:0] funct3 = ins[14:12];
wire [6:0] funct7 = ins[31:25];

wire [4:0] rd = ins[11:7];
wire [4:0] rs1 = ins[19:15];
wire [4:0] rs2 = ins[24:20];
wire [11 : 0] immI = ins[31:20];
wire [4:0] immI_star = ins[24:20];
wire [11:0] immS = {ins[31:25], ins[11:7]};
wire [11:0] immB = {ins[31], ins[7], ins[30:25], ins[11:8], 1'b0};
wire [31:12] immU = ins[31:12];
wire [20:1] immJ = {ins[31], ins[19:12], ins[20], ins[30:21], 1'b0};

localparam RISC_R = 7'b0110011;
localparam RISC_I = 7'b0010011;
localparam RISC_S = 7'b0100011;
localparam RISC_B = 7'b1100011;

// special type
localparam JAL = 7'b1101111;
localparam JALR = 7'b1100111;
localparam LUI = 7'b0110111;
localparam AUIPC = 7'b0010111;

// _ represent boolean
wire _rs1 = opcode == RISC_R || opcode == RISC_I || opcode == RISC_S || opcode == RISC_B || opcode == JALR;
wire _rs2 = opcode == RISC_R || opcode == RISC_S || opcode == RISC_B;


// if last addr inst = now, now need to change 
wire _change = ins_ready && (last_addr != pc);


// if instruction not ready, tell lsb/rob/rs valid <= 0
reg [31:0] last_addr;

wire [6:0] op_map;

always @(posedge clk_in) begin
  if(rst_in) begin
    // reset (TODO)

  end else begin
    // default config
    
    if(rdy_in) begin
      // decode try to map opcode, next circle issue? no! one-circle.
      

      // if ins_ready, decode ins
      if(_change) begin
        
      end

      // send to ROB, LS, LSB
    end 
  end
end
endmodule