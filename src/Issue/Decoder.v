`include "const.v"
// circle 1 ins -> decode_imm.. -> 

// 3 part

// 1. with fetcher : decide whether to fetch /
// 2. with decoder: decode ins to ROB/RS/LSB ins's type
// 3. with execution: wire read other's block's value/dependency & whether block idle; 
// reg show ROB/RS/LSB ins's arrived. 


module Decoder (
  input wire clk_in,  // system clock signal
  input wire rst_in,  // reset signal
  input wire rdy_in,  // ready signal, pause cpu when low
  // needed wire

  // ins input /from.to insFetcher
  input wire ins_ready,
  input wire [31 : 0] ins,
  input wire [31 : 0] pc, // {0, bit} real_ifetcher_pc + prediction result.
  input wire [31 : 0] predict_nxt_pc,

  // output to insFetcher(stall)
  output wire IFetcher_stall,
  output reg [31: 0] IFetcher_new_addr,
  output reg IFetcher_clear,

  // input from ROB
  input wire ROB_ready,
  input wire [4: 0] rob_tail,
  input wire [`ROB_WIDTH_BIT - 1: 0] ROB_del_Dep,
  input wire rob_full,

  // output to ROB
  output reg ROB_inst_valid,
  output reg ROB_inst_ready,
  output reg [31 : 0] ROB_ins_value,
  output reg [4 : 0] ROB_ins_rd,
  output reg [`ROB_TYPE - 1:0] ROB_ins_Type, 
  output reg [31 : 0] ROB_ins_Addr,
  output reg [31 : 0] ROB_ins_jpAddr,

  input wire rs_full,
  
  // output to RS
  output reg RS_inst_valid,
  output reg [`RS_TYPE - 1 : 0] RS_ins_Type,
  // no QI -> is_qi = 0, qi = real_value,
  output wire [31 : 0] RS_ins_rs1,
  output wire [31 : 0] RS_ins_rs2,
  output wire [31 : 0] RS_imm,
  output wire RS_is_Qi,
  output wire RS_is_Qj,
  output wire [4 : 0] RS_Qi,
  output wire [4 : 0] RS_Qj,
  output wire [4 : 0] RS_rob_id,

  input wire lsb_full,
  // output to LSB
  output reg LSB_ins_valid,
  output reg [`LSB_TYPE - 1 : 0] LSB_ins_Type, // b,h,w / s,l 
  output wire [4 : 0] LSB_ins_rd, // rob_id,
  output wire [31 : 0] LSB_ins_rs1,
  output wire [31 : 0] LSB_ins_rs2,
  output wire LSB_is_Qi,
  output wire LSB_is_Qj,
  output wire [4 : 0] LSB_Qi,
  output wire [4 : 0] LSB_Qj,
  output wire [31 : 0] LSB_imm,

  // from/to REGF
  output wire [4: 0] ask_reg_id1,
  output wire [4: 0] ask_reg_id2,
  input wire [31: 0] REGF_ret_val_id1,
  input wire [31: 0] REGF_ret_val_id2,
  input wire REGF_dep_rs1,
  input wire REGF_dep_rs2,
  input wire [`ROB_WIDTH_BIT - 1: 0] REGF_ret_ROB_id1,
  input wire [`ROB_WIDTH_BIT - 1: 0] REGF_ret_ROB_id2
);

wire [31 : 0]real_ifetcher_pc = {pc[31 : 1], 1'b0};

localparam RISC_R = 7'b0110011;
localparam RISC_I = 7'b0010011;
localparam RISC_L = 7'b0000011;
localparam RISC_S = 7'b0100011;
localparam RISC_B = 7'b1100011;

// special type
localparam JAL = 7'b1101111;
localparam JALR = 7'b1100111;
localparam LUI = 7'b0110111;
localparam AUIPC = 7'b0010111;

// wire decode input inst immediately
wire [6:0] opcode = ins[6:0];
wire [2:0] funct3 = ins[14:12];
wire [6:0] funct7 = ins[31:25];
wire [4:0] rd = ins[11:7];
wire [4:0] rs1 = ins[19:15];
wire [4:0] rs2 = ins[24:20];
wire [11:0] immI = ins[31:20]; // I_STAR merged into I
wire [4:0] immI_star = ins[24:20];
wire [11:0] immS = {ins[31:25], ins[11:7]};
wire [11:0] immB = {ins[31], ins[7], ins[30:25], ins[11:8], 1'b0};
wire [31:12] immU = ins[31:12];
wire [20:1] immJ = {ins[31], ins[19:12], ins[20], ins[30:21], 1'b0};

// _ represent boolean


wire _rs1 = opcode == RISC_R || opcode == RISC_I || opcode == RISC_S || opcode == RISC_B || opcode == JALR;
wire _rs2 = opcode == RISC_R || opcode == RISC_S || opcode == RISC_B;
wire _lsb = (opcode == RISC_S || opcode == RISC_L);
wire _rs = (opcode == RISC_B || opcode == RISC_R || opcode == RISC_I);
// ROB always needed

wire [3:0] lsb_op = {~opcode[5], funct3};
wire _Jalr = opcode == JALR;

// if last addr inst = now, now need to change 
wire _change = ins_ready && (last_addr != real_ifetcher_pc);
wire _work = (!_lsb || !lsb_full) && (!_rs || !rs_full) && !rob_full && (!_Jalr || !_QI);

// if instruction not ready, tell lsb/rob/rs valid <= 0
reg _QI, _QJ;
reg [4:0] QI, QJ;
reg [31:0] last_addr;
reg [31 : 0] rs1_val, rs2_val, lsb_imm, rs_imm;

always @(posedge clk_in) begin
  if(rst_in) begin
    // reset all output reg
    last_addr <= 32'b0;
    ROB_inst_valid <= 0;
    ROB_inst_ready <= 0;
    ROB_ins_value <= 0;
    ROB_ins_Type <= 0;
    ROB_ins_rd <= 0;
    ROB_ins_Addr <= 0;
    ROB_ins_jpAddr <= 0;

    RS_inst_valid <= 0;
    RS_ins_Type <= 0;
    LSB_ins_valid <= 0;
    LSB_ins_Type <= 0;
    rs1_val <= 0;
    rs2_val <= 0;
    lsb_imm <= 0;
    rs_imm <= 0;

    IFetcher_clear <= 0;
    IFetcher_new_addr <= 0;

    _QI <= 0;
    _QJ <= 0;
    QI <= 0;
    QJ <= 0;
    last_addr <= 32'hffffffff;

  end else begin
    // default config
    if(rdy_in) begin
      // decode try to map opcode, next circle issue? no! one-circle.
      // if ins_ready, decode ins
      ROB_inst_valid <= 0;
      RS_inst_valid <= 0;
      LSB_ins_valid <= 0;
      if(_change && _work) begin
        // ROB/LSB/RS_INS_TYPE
        case(opcode) 
          RISC_R: ROB_ins_Type <= `TypeRd;
          RISC_I: ROB_ins_Type <= `TypeRd;
          RISC_L: ROB_ins_Type <= `TypeRd;
          RISC_S: ROB_ins_Type <= `TypeSt;
          RISC_B: ROB_ins_Type <= `TypeBr;
        endcase

        last_addr <= ROB_ins_Addr;

        ROB_inst_valid <= 1'b1;
        RS_inst_valid <= _rs;
        LSB_ins_valid <= _lsb;

        LSB_ins_Type <= lsb_op;
        // RS_ins_Type <= (opcode == RISC_R || opcode == RISC_I || opcode == RISC_B) ? funct3 : 5'b00000;
        if(opcode == RISC_R) begin
          case(funct3)
            3'b000: RS_ins_Type <= funct7[5]? `SUB : `ADD;
            3'b001: RS_ins_Type <= `SLL;
            3'b010: RS_ins_Type <= `SLT;
            3'b011: RS_ins_Type <= `SLTU;
            3'b100: RS_ins_Type <= `XOR;
            3'b101: RS_ins_Type <= funct7[5]? `SRA : `SRL;
            3'b110: RS_ins_Type <= `OR;
            3'b111: RS_ins_Type <= `AND;
            default: RS_ins_Type <= 5'b00000;
          endcase
        end else if(opcode == RISC_I) begin
          case(funct3)
            3'b000: RS_ins_Type <= `ADDI;
            3'b001: RS_ins_Type <= `SLLI;
            3'b010: RS_ins_Type <= `SLTI;
            3'b011: RS_ins_Type <= `SLTIU;
            3'b100: RS_ins_Type <= `XORI;
            3'b101: RS_ins_Type <= funct7[5]? `SRAI : `SRLI;
            3'b110: RS_ins_Type <= `ORI;
            3'b111: RS_ins_Type <= `ANDI;
            default: RS_ins_Type <= 5'b00000;
          endcase
        end
        else if(opcode == RISC_B) begin
          case(funct3)
            3'b000: RS_ins_Type <= `BEQ;
            3'b001: RS_ins_Type <= `BNE;
            3'b100: RS_ins_Type <= `BLT;
            3'b101: RS_ins_Type <= `BGE;
            3'b110: RS_ins_Type <= `BLTU;
            3'b111: RS_ins_Type <= `BGEU;
            default: RS_ins_Type <= 5'b00000;
          endcase
        end 
        // reg <=       

        rs_imm <= opcode == RISC_I ?((funct3 == 3'b001 || funct3 == 3'b101)? immI_star : immI) : opcode == RISC_B? immB :  32'b0;
        lsb_imm <= opcode == RISC_L ? immI : immS;

        rs1_val <= REGF_ret_val_id1;
        _QI <= _rs1 && REGF_dep_rs1;
        QI <= REGF_ret_ROB_id1; 

        rs2_val <= REGF_ret_val_id2;
        _QJ <= _rs2 && REGF_dep_rs2;
        QJ <= REGF_ret_ROB_id2;

        // rob special ins
        ROB_inst_ready <= opcode == JAL || opcode == JALR || opcode == LUI || opcode == AUIPC;
        ROB_ins_rd <= rd;
        ROB_ins_Addr <= real_ifetcher_pc;
        // jump addr estimated by ROB
        case(opcode)
          JAL: begin
            ROB_ins_value <= real_ifetcher_pc + 4;
          end
          JALR: begin
            ROB_ins_value <= real_ifetcher_pc + 4;
            IFetcher_clear <= 1;
            IFetcher_new_addr <= (rs1_val + {{20{immI[10]}}, immI}) & ~32'b1;
          end
          LUI: ROB_ins_value <= {immU, 12'b0};
          AUIPC: ROB_ins_value <= real_ifetcher_pc + {immU, 12'b0};
          RISC_B: begin
            //[pc] is branch , predict_pc result in b-predictor? 
            ROB_ins_jpAddr <= predict_nxt_pc;
          end
        endcase
      end

    end 
  end
end

// send to ifetcher, no need to read ins
assign IFetcher_stall = _change && !_work;

// output wire : ask
assign ask_reg_id1 = rs1;
assign ask_reg_id2 = rs2;

// RS output wire :
assign RS_ins_rs1 = rs1_val;
assign RS_Qi = QI;
assign RS_is_Qi = _QI;

assign RS_ins_rs2 = rs2_val;
assign RS_Qj = QJ;
assign RS_is_Qj = _QJ;

assign RS_rob_id = rob_tail;
assign RS_imm = rs_imm;

// LSB output wire :
assign LSB_ins_rs1 = rs1_val;
assign LSB_Qi = QI;
assign LSB_is_Qi = _QI;

assign LSB_ins_rs2 = rs2_val;
assign LSB_Qj = QJ;
assign LSB_is_Qj = _QJ;

assign LSB_ins_rd = rob_tail;
assign LSB_imm = lsb_imm;


endmodule