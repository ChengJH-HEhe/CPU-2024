`define ROB_WIDTH_BIT 5
`define ROB_WIDTH (1 << `ROB_WIDTH_BIT)

`define RS_WIDTH_BIT 3
`define RS_WIDTH (1 << `RS_WIDTH_BIT)

`define LSB_TYPE 3
`define LSB_WIDTH_BIT 3


`define ROB_TYPE 3

`define TypeJp  3'b0
`define TypeSt  3'b1
`define TypeBr  3'b10
`define TypeRd  3'b11

`define RS_TYPE 5

// GENERATE ALL OPCODE TO 1,2,...32.
// ADD SUB AND OR XOR SLL SRL SRA SLT SLTU ADDI ANDI ORI XORI SLLI
// SRLI SRAI SLTI SLTIU LB LBU LH LHU LW SB SH SW 
// BEQ BGE BGEU BLT BLTU BNE 
// JAL JALR AUIPC LUI

`define NULL 6'd0
`define ADD 6'd1 
`define SUB 6'd2
`define AND 6'd3
`define OR 6'd4
`define XOR 6'd5
`define SLL 6'd6
`define SRL 6'd7
`define SRA 6'd8
`define SLT 6'd9
`define SLTU 6'd10
`define ADDI 6'd11
`define ANDI 6'd12
`define ORI 6'd13
`define XORI 6'd14
`define SLLI 6'd15
`define SRLI 6'd16
`define SRAI 6'd17
`define SLTI 6'd18
`define SLTIU 6'd19
`define LB 6'd20
`define LH 6'd21
`define LW 6'd22
`define LBU 6'd23
`define LHU 6'd24
`define SB 6'd25
`define SH 6'd26
`define SW 6'd27
`define BEQ 6'd28
`define BNE 6'd29
`define BLT 6'd30
`define BGE 6'd31
`define BLTU 6'd32
`define BGEU 6'd33
`define JAL 6'd34
`define JALR 6'd35
`define LUI 6'd36
`define AUIPC 6'd37




