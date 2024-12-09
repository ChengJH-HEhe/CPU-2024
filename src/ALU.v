`include "const.v"

module ALU (
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
  input  wire					        rdy_in,			// ready signal, pause cpu when low
  input wire [6 : 0] alu_op ,
  input wire [31 : 0] Vi ,
  input wire [31 : 0] Vj ,
  input wire [31 : 0] imm,
  input wire [4 : 0] rd_in,
  input wire [31:0] pc,
  //

  output reg [31 : 0] res,
  output reg [31 : 0] pc_dest,
  output reg [4 : 0] rd_out,
  output reg jpp,
  output reg valid // ready

);
  always @(*) begin
    rd_out = rd_in;
    valid = (alu_op > 0);
    pc_dest = pc;
    jpp = 0;
    res = 0;
      // work
      // 
    case(alu_op) 
      `ADD: begin
        res = Vi + Vj;
      end
      `SUB: begin
        res = Vi - Vj;
      end
      `AND: begin
        res = Vi & Vj;
      end
      `OR: begin
        res = Vi | Vj;
      end
      `XOR: begin
        res = Vi ^ Vj;
      end
      `SLL: begin
        res = Vi << Vj;
      end
      `SRL: begin
        res = Vi >> Vj;
      end
      `SRA: begin
        res = $signed(Vi) >> Vj;
      end
      `SLT: begin
        res = (Vi < Vj) ? 1 : 0;
      end
      `SLTU: begin
        res = (Vi < Vj) ? 1 : 0;
      end
      `ADDI: begin
        res = Vi + imm;
      end
      `ANDI: begin
        res = Vi & imm;
      end
      `ORI: begin
        res = Vi | imm;
      end
      `XORI: begin
        res = Vi ^ imm;
      end
      `SLLI: begin
        res = Vi << imm[4:0];
      end
      `SRLI: begin
        res = Vi >> imm[4:0];
      end
      `SRAI: begin
        res = $signed(Vi) >>> imm[4:0];
      end
      `SLTI: begin
        res = ($signed(Vi) < $signed(imm)) ? 1 : 0;
      end
      `SLTIU: begin
        res = (Vi < imm) ? 1 : 0;
      end
      `BEQ: begin
        if(Vi == Vj) begin
          jpp = 1;
        end
        pc_dest = pc + imm;
      end
      `BNE: begin
        if(Vi != Vj) begin
          jpp = 1;
        end
        pc_dest = pc + imm;
      end
      `BLT: begin
        if($signed(Vi) < $signed(Vj)) begin
          jpp = 1;
        end
        pc_dest = pc + imm;
      end
      `BGE: begin
        if($signed(Vi) >= $signed(Vj)) begin
          jpp = 1;
        end
        pc_dest = pc + imm;
      end
      `BLTU: begin
        if(Vi < Vj) begin
          jpp = 1;
        end
        pc_dest = pc + imm;
      end
      `BGEU: begin
        if(Vi >= Vj) begin
          jpp = 1;
        end
        pc_dest = pc + imm;
      end
      `JAL: begin
        res = pc + 4;
        pc_dest = pc + imm;
        jpp = 1;
      end
      `JALR: begin
        res = pc + 4;
        pc_dest = (Vi + imm) & 32'hFFFFFFFE;
        jpp = 1;
      end
      `AUIPC: begin
        res = pc + imm;
      end
      `LUI: begin
        res = imm;
      end 
      default: begin
        res = 0;
      end
    endcase
  end
endmodule