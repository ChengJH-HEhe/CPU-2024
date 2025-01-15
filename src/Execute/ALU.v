`include "const.v"

module ALU
    (input wire clk_in,
     // system clock signal
     input wire rst_in,
     // reset signal
     input wire rdy_in,
     // ready signal, pause cpu when low
     input wire [5 : 0] alu_op,
     input wire [31 : 0] Vi,
     input wire [31 : 0] Vj,
     input wire [31 : 0] imm,
     input wire [4 : 0] rd_in,
     input wire [31 : 0] pc,
     input wire Itype, 
     //

     output reg [31 : 0] res,
     output reg [4 : 0] rd_out,
     output reg valid // ready
    );
  wire [31 : 0] imm_rd = {{20{imm[11]}}, imm[11 : 0]};
  integer file;
  always @(posedge clk_in) begin
    if (rst_in) begin
      valid <= 0;
      rd_out <= 0;
      res <= 0;
    end else if (!rdy_in) begin
      // do nothing
    end else if (!alu_op) begin
      valid <= 0;
    end else begin
      rd_out <= rd_in;
      valid <= 1'b1;
      res <= 0;
      // work
      //
      case (alu_op)
        `ADD: begin
          res <= Vi + Vj;
        end
        `SUB: begin
          res <= Vi - Vj;
        end
        `AND: begin
          res <= Vi & Vj;
        end
        `OR: begin
          res <= Vi | Vj;
        end
        `XOR: begin
          res <= Vi ^ Vj;
        end
        `SLL: begin
          res <= Vi << Vj;
        end
        `SRL: begin
          res <= Vi >> Vj;
        end
        `SRA: begin
          res <= $signed(Vi) >> Vj;
        end
        `SLT: begin
          res <= (Vi < Vj) ? 1 : 0;
        end
        `SLTU: begin
          res <= (Vi < Vj) ? 1 : 0;
        end
        `ADDI: begin
          res <= Vi + imm_rd;
          // $display("ADDI Vi=%d Vj=%d", Vi, {{20{imm[11]}}, imm});
        end
        `ANDI: begin
          res <= Vi & imm_rd;
        end
        `ORI: begin
          res <= Vi | imm_rd;
        end
        `XORI: begin
          res <= Vi ^ imm_rd;
        end
        `SLLI: begin
          res <= Vi << imm[4 : 0];
        end
        `SRLI: begin
          res <= Vi >> imm[4 : 0];
        end
        `SRAI: begin
          res <= $signed(Vi) >>> imm[4 : 0];
        end
        `SLTI: begin
          res <= ($signed(Vi) < $signed(imm_rd)) ? 1 : 0;
        end
        `SLTIU: begin
          res <= (Vi < imm_rd) ? 1 : 0;
        end
        `BEQ: begin
          // if(Vi == Vj) begin
          //   jpp = 1;
          // end
          res <= pc + ((Vi == Vj) ? imm_rd + 1 : (Itype?4:2));
        end
        `BNE: begin
          res <= pc + ((Vi != Vj) ? imm_rd + 1 : (Itype?4:2));
        end
        `BLT: begin
          res <= pc + ($signed(Vi) < $signed(Vj) ? imm_rd + 1 : 4);
        end
        `BGE: begin
          res <= pc + ($signed(Vi) >= $signed(Vj) ? imm_rd + 1 : 4);
        end
        `BLTU: begin
          res <= pc + ((Vi < Vj) ? imm_rd + 1 : 4);
        end
        `BGEU: begin
          res <= pc + ((Vi >= Vj) ? imm_rd + 1 : 4);
        end
        `LUI: begin
          res <= imm_rd;
        end
        default: begin
          res <= 0;
        end
      endcase
      // if(alu_op == `BEQ && pc == 320)
      //   $display("pc=%d op=%d rs1=%d rs2=%d", pc, alu_op, Vi, Vj);
    end
  end
endmodule