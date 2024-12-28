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
  input wire [4: 0] rob_tail,
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
  output reg [31 : 0] RS_pc,
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
// if instruction not ready, tell lsb/rob/rs valid <= 0

reg _QI, _QJ;
reg [4:0] QI, QJ;
reg [31:0] last_addr;
reg [31 : 0] rs1_val, rs2_val, lsb_imm, rs_imm;
reg [4:0] ins_rob_id;

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
wire is_Itype = ins[1:0] == 2'b11;

wire [2:0] funct3 = is_Itype ? ins[14:12] : ins[15:13];
wire [3:0] funct4 = is_Itype ? 4'b0 : ins[15:12];
wire [6:0] funct7 = ins[31:25];
wire [4:0] ins_6_2 = ins[6:2];
wire [4:0] ins_11_7 = ins[11:7];
wire [1:0] ins_11_10 = ins[11:10];
wire [2:0] ins_9_7 = ins[9:7];


// wire [20:1] immJ = {ins[31], ins[19:12], ins[20], ins[30:21], 1'b0}; unused

wire [6:0] opcode = is_Itype ? ins[6:0]: //C-type
  (ins[1:0] == 2'b10) ?
    ((funct3 == 3'b000) ? RISC_I :  // SLLI
    (funct3 == 3'b010) ? RISC_L :  // LWSP
    (funct3 == 3'b100) ? (ins_6_2 == 5'b0 ? JALR : RISC_R) : 
      // ins[11] = 0 JR, MV
      // funct3 = 3'b100 ins[11] = 1 JALR, ADD
    (funct3 == 3'b110) ? RISC_S : 7'b0) // SWSP 7
 : (ins[1:0] == 2'b01)?
    ((funct3 == 3'b000) ? RISC_I :  // ADDI
    (funct3 == 3'b001) ? JAL :  // JAL
    (funct3 == 3'b010) ? LUI :  // LI in c-type immli_u be calced
    (funct3 == 3'b011) ? (ins_11_7 == 2 ? RISC_I : LUI) :  // ADDI16SP , LUI
    (funct3 == 3'b100) ? (ins_11_10 == 2'b11 ? RISC_R : RISC_I) : 
     // SRLI, SRAI, ANDI/ SUB,XOR,OR,AND 
    (funct3 == 3'b101) ? JAL : // J 
                        RISC_B) // 110: BEQZ 111:BNEZ 15
  // ins[1:0] == 2'b00
 : (funct3 == 3'b000) ? RISC_I : // ADDI4SPN
 (funct3 == 3'b010) ? RISC_L : // LW
 (funct3 == 3'b110) ? RISC_S : 7'b0 // SW 3
;
wire [11:0] imm_andI = {{3{ins[12]}}, ins[4:3], ins[5], ins[2], ins[6], 4'b0};
wire [4:0] rd = (is_Itype)? ins[11:7] : 
  (ins[1:0] == 2'b10) ? 
    ((funct4 == 4'b1001 && ins_6_2 == 5'b0) ? 5'b1 : ins[11:7])
  : (ins[1:0] == 2'b01) ? (funct3 == 3'b101) ? 5'b0 : // j
  (ins[15] ? {1'b0,1'b1,ins[9:7]} : // 1 
  (funct3 == 3'b001) ? 5'b1 : // jal
  ins[11:7]) 
  : (ins[1:0] == 2'b00) ? {1'b0,1'b1,ins[4:2]} : 5'b0;  
  // JALR rs1 : 
wire [4:0] rs1 = is_Itype ? ins[19:15]
    : (ins[1:0] == 2'b10) ? ( (ins[14:13] == 2'b10) ? 5'd2 : // lwsp ,swsp
       (ins[15:12] == 4'b1000 && ins_6_2 != 5'b0)? 5'd0 : ins[11:7]) // mv; jr
    : (ins[1:0] == 2'b01) ? 
      (ins[15] ? {1'b0,1'b1,ins[9:7]} : // other R
        ins[11:7]) 
    : (ins[1:0] == 2'b00) ? ((funct3 == 3'b000) ? 5'b10 : {1'b0,1'b1,ins[9:7]}) : 5'b0;
    // MV 0
wire [4:0] rs2 = is_Itype ? ins[24:20]
    : (ins[1:0] == 2'b10) ? ins[6:2]
    : (ins[1:0] == 2'b01 && ins[15:14] == 2'b11) ? 5'b0 : {1'b0,1'b1,ins[4:2]};
// ADDI, ADDI16SP, ANDI, ADDI4SPN
wire [11:0] immI = is_Itype ? ins[31:20] : 
  (ins[1:0] == 2'b01) ? 
                        // ANDI
    (((funct3 == 3'b000) || (funct3 == 3'b100)) ? {{7{ins[12]}},ins[6:2]} : 
                        (imm_andI)) :
                        // 12-11 10-7 6 5
                        // ADDI4SPN 
  (ins[1:0] == 2'b00) ? {2'b0,ins[10:7],ins[12:11],ins[5],ins[6],2'b0}:12'b0;
 // I_STAR merged into I

wire [4:0] immI_star = is_Itype ? ins[24:20] : {ins[12], ins[6:2]};

wire [31:0] immU = is_Itype ? {ins[31:12], 12'b0} : 
// c.li, c.lui
ins[13]? {{15{ins[12]}},ins[6:2],12'b0} : {{27{ins[12]}}, ins[6:2]};

// lw(sp) still here
wire [11:0] immS = is_Itype ? {ins[31:25], ins[11:7]} : 
(ins[1:0] == 2'b00) ? {5'b0, ins[5], ins[12:10], ins[6], 2'b0} 
                    : ins[15]? {4'b0, ins[8:7], ins[12:9], 2'b0}
                        : {4'b0, ins[3:2],ins[12],ins[6:4],2'b0};
wire [11:0] immB = is_Itype ? {ins[31], ins[7], ins[30:25], ins[11:8], 1'b0}
                  : {{5{ins[12]}}, ins[6:5],ins[2],ins[11:10],ins[4:3],1'b0};
// _ represent boolean


wire _rs1 = opcode == RISC_R || opcode == RISC_I || opcode == RISC_S || opcode == RISC_B || opcode == JALR;
wire _rs2 = opcode == RISC_R || opcode == RISC_S || opcode == RISC_B;
wire _lsb = (opcode == RISC_S || opcode == RISC_L);
wire _rs = (opcode == RISC_B || opcode == RISC_R || opcode == RISC_I);
// ROB always needed

wire [3:0] lsb_op = is_Itype ? {opcode[5], funct3} : {funct3[2], 1'b0, funct3[1:0]};
wire _Jalr = opcode == JALR;


// if last addr inst = now, now need to change 
wire _change = ins_ready && (last_addr != real_ifetcher_pc);
wire _work = (!_lsb || !lsb_full) && (!_rs || !rs_full) && !rob_full && (!_Jalr || !REGF_dep_rs1);


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
    ins_rob_id <= 0;
    last_addr <= 32'hffffffff;

  end else begin
    // default config
    if(rdy_in) begin
      // decode try to map opcode, next circle issue? no! one-circle.
      // if ins_ready, decode ins
      IFetcher_clear <= 0;
      if(_change && _work) begin
        // ROB/LSB/RS_INS_TYPE
        case(opcode) 
          RISC_L: ROB_ins_Type <= `TypeLd;
          RISC_S: ROB_ins_Type <= `TypeSt;
          RISC_B: ROB_ins_Type <= `TypeBr;
          default: 
            ROB_ins_Type <= `TypeRd;
        endcase

        last_addr <= ROB_ins_Addr;

        ROB_inst_valid <= 1'b1;
        RS_inst_valid <= _rs;
        LSB_ins_valid <= _lsb;

        LSB_ins_Type <= lsb_op;
        // RS_ins_Type <= (opcode == RISC_R || opcode == RISC_I || opcode == RISC_B) ? funct3 : 5'b00000;
        if(opcode == RISC_R) begin
          if(is_Itype)
          case(funct3)
            3'b000: RS_ins_Type <= funct7[5]? `SUB : `ADD;
            3'b001: RS_ins_Type <= `SLL;
            3'b010: RS_ins_Type <= `SLT;
            3'b011: RS_ins_Type <= `SLTU;
            3'b100: RS_ins_Type <= `XOR;
            3'b101: RS_ins_Type <= funct7[5]? `SRA : `SRL;
            3'b110: RS_ins_Type <= `OR;
            3'b111: RS_ins_Type <= `AND;
          endcase
          else
          case(ins[1:0])
            2'b10: RS_ins_Type <= `ADD;
            2'b01: 
              case(ins[12]) 
                1'b0: 
                  case(ins[6:5])
                    2'b00: RS_ins_Type <= `SUB;
                    2'b01: RS_ins_Type <= `XOR;
                    2'b10: RS_ins_Type <= `OR;
                    2'b11: RS_ins_Type <= `AND;
                  endcase
                1'b1:
                  $display("R ins[12] = 1'b1 illegal");
              endcase
            default: $display("R Type Wrong");
          endcase
        end else if(opcode == RISC_I) begin
          if(is_Itype)
          case(funct3)
            3'b000: RS_ins_Type <= `ADDI;
            3'b001: RS_ins_Type <= `SLLI;
            3'b010: RS_ins_Type <= `SLTI;
            3'b011: RS_ins_Type <= `SLTIU;
            3'b100: RS_ins_Type <= `XORI;
            3'b101: RS_ins_Type <= funct7[5]? `SRAI : `SRLI;
            3'b110: RS_ins_Type <= `ORI;
            3'b111: RS_ins_Type <= `ANDI;
          endcase
          else
          case(ins[1:0])
            2'b10: RS_ins_Type <= `SLLI;
            2'b01: begin
              if(funct3 == 3'b000 || funct3 == 3'b011) 
                RS_ins_Type <= `ADDI;
              else if(funct3 == 3'b100) begin
                case(ins[11:10])
                  2'b00: RS_ins_Type <= `SRLI;
                  2'b01: RS_ins_Type <= `SRAI;
                  2'b10: RS_ins_Type <= `ANDI;
                  default:
                    $display("I ins[11:10] wrong!");
                endcase
              end else $display("I funct3 wrong");
            end
            2'b00: RS_ins_Type <= `ADDI;
            default:
              $display("I funct3 wrong");
          endcase
        end
        else if(opcode == RISC_B) begin
          if(is_Itype)
          case(funct3)
            3'b000: RS_ins_Type <= `BEQ;
            3'b001: RS_ins_Type <= `BNE;
            3'b100: RS_ins_Type <= `BLT;
            3'b101: RS_ins_Type <= `BGE;
            3'b110: RS_ins_Type <= `BLTU;
            3'b111: RS_ins_Type <= `BGEU;
            default: RS_ins_Type <= 5'b00000;
          endcase
          else begin
            RS_ins_Type <= ins[13] ? `BNE : `BEQ;
          end
        end 
        // $display("pc=%h rd=%d,rs1=%d,rs2=%d, rs_imm=%d, lsb_imm=%d", real_ifetcher_pc, rd,rs1,rs2,rs_imm, lsb_imm);
        rs_imm <= 
        opcode == RISC_I ? 
          (is_Itype ? ((funct3 == 3'b001 || funct3 == 3'b101)? immI_star : immI) 
            : (((ins[1:0] == 2'b01 && ins[15:13] == 3'b100) || (ins[1:0] == 2'b10 && ins[15:13] == 3'b010)) ? immI_star : immI))
         : opcode == RISC_B? immB :  32'b0;
        lsb_imm <= (is_Itype && opcode == RISC_L) ? immI 
          : immS;

        rs1_val <= REGF_ret_val_id1;
        _QI <= _rs1 && REGF_dep_rs1;
        QI <= REGF_ret_ROB_id1; 

        rs2_val <= REGF_ret_val_id2;
        _QJ <= _rs2 && REGF_dep_rs2;
        QJ <= REGF_ret_ROB_id2;

        ins_rob_id <= rob_tail;
        
        // rob special ins
        ROB_inst_ready <= opcode == JAL || opcode == JALR || opcode == LUI || opcode == AUIPC;
        ROB_ins_rd <= rd;
        ROB_ins_Addr <= real_ifetcher_pc;

        RS_pc <= real_ifetcher_pc;
        
        // jump addr estimated by ROB
        case(opcode)
          JAL: begin
            ROB_ins_value <= real_ifetcher_pc + (is_Itype ? 4 : 2);
          end
          JALR: begin
            ROB_ins_value <= real_ifetcher_pc + (is_Itype ? 4 : 2);
            IFetcher_clear <= 1;
            // JALR  TODO
            IFetcher_new_addr <= is_Itype ? ((REGF_ret_val_id1 + {{20{immI[10]}}, immI}) & ~32'b1) : REGF_ret_val_id1;
          end
          LUI: ROB_ins_value <= immU;
          
          AUIPC: ROB_ins_value <= real_ifetcher_pc + {immU, 12'b0};
          RISC_B: begin
            //[pc] is branch , predict_pc result in b-predictor? 
            ROB_ins_jpAddr <= predict_nxt_pc;
          end
        endcase
      end else begin
        ROB_inst_valid <= 1'b0;
        RS_inst_valid <= 1'b0;
        LSB_ins_valid <= 1'b0;
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