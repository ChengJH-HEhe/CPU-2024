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
  output reg valid // ready

);
  always @(*) begin
    rd_out = rd_in;
    valid = (alu_op > 0);
    pc_dest = pc;
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
        // if(Vi == Vj) begin
        //   jpp = 1;
        // end
          pc_dest = pc + (Vi == Vj)? imm + 1 : 4;
      end
      `BNE: begin
          pc_dest = pc + (Vi != Vj)? imm + 1 : 4;
      end
      `BLT: begin
          pc_dest = pc + $signed(Vi) < $signed(Vj)? imm + 1 : 4;
      end
      `BGE: begin
          pc_dest = pc + $signed(Vi) >= $signed(Vj)? imm + 1 : 4;
      end
      `BLTU: begin
          pc_dest = pc + Vi < Vj? imm + 1 : 4;
      end
      `BGEU: begin
          pc_dest = pc + Vi >= Vj? imm + 1 : 4;
      end
      default: begin
        res = 0;
      end
    endcase
  end
endmodule