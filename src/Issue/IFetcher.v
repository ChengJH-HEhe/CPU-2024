`include "const.v"

module IFetcher (
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
    input  wire					rdy_in,			// ready signal, pause cpu when low
    
    input wire [31 : 0] input_ins,
    input wire [31 : 0] ins_pc,
    input wire input_ins_ready,
    
    input wire stall, // pause
    
    input wire jalr_clear, // clear
    input wire [31:0] jalr_pc,

    // icache
    output reg [31 : 0] to_Cache_pc,
    output wire fetch_able,
    // decoder ok to receive?(no need)

    // Decoder
    output reg output_ins_ready,
    output reg [31 : 0] output_ins,
    output reg [31 : 0] output_pc,
    output reg [31 : 0] predict_nxt_pc,

    // b-predictor
    output wire [31 : 0] branch_ins,
    output wire [31 : 0] branch_pc,
    output wire Itype,
    input wire [31 : 0] predict_pc,

    // ROB JALR
    input wire br_reset,
    input wire [31 : 0] br_pc
);

localparam JAL = 7'b1101111;
localparam JALR = 7'b1100111;

wire is_Itype = input_ins[1:0] == 2'b11;
assign Itype = is_Itype;
// jal 12-11-10:9-8-7-6-5:3-2
// imm[11|4|9:8|10|6|7|3:1|5]
wire [20:1] immJ = is_Itype ? {input_ins[31], input_ins[19:12], input_ins[20], input_ins[30:21]}
        : {{10{input_ins[12]}},input_ins[8], input_ins[10:9], input_ins[6], input_ins[7], input_ins[2], input_ins[11], input_ins[5:3]};
reg reg_stall; // 0: IDLE, 1: BUSY waiting 2: stall!
assign branch_ins = input_ins;
assign branch_pc = to_Cache_pc;
assign fetch_able = !reg_stall;
always @(posedge clk_in) begin
    if(rst_in) begin
        to_Cache_pc <= 32'b0;
        output_ins_ready <= 1'b0;
        output_ins <= 32'b0;
        output_pc <= 32'b0;
        reg_stall <= 1'b0;
    end else if(~rdy_in) begin
    end else if(br_reset || (reg_stall && jalr_clear)) begin
        to_Cache_pc <= br_reset ? {br_pc[31:1], 1'b0} : jalr_pc;
        output_ins_ready <= 1'b0;
        output_ins <= 32'b0;
        output_pc <= 32'b0;
        reg_stall <= 1'b0;
    end  else if(!reg_stall && !stall && input_ins_ready && input_ins) begin
        // ready to fetch
        output_ins_ready <= 1'b1;
        output_pc <= {to_Cache_pc[31:1], 1'b0};
        output_ins <= input_ins;
        if((is_Itype && input_ins[6:0] == JAL) || (!is_Itype && input_ins[1:0] == 2'b01 && input_ins[14:13] == 2'b01)) begin
            to_Cache_pc <= to_Cache_pc + {{11{immJ[20]}}, immJ, 1'b0};
            predict_nxt_pc <= to_Cache_pc + {{11{immJ[20]}}, immJ, 1'b0}; // inform the decoder of predictor result
            //  $display("%h -> %h", to_Cache_pc + immJ, to_Cache_pc + {{11{immJ[20]}}, immJ, 1'b0});
        end else if((is_Itype && input_ins[6:0] == JALR) || (!is_Itype && input_ins[15:13] == 3'b100 && input_ins[6:2] == 5'b0)) begin
            reg_stall <= 1'b1; // JALR? nop
        end else begin
            to_Cache_pc <= {predict_pc[31:1],1'b0}; // next_circle
            predict_nxt_pc <= predict_pc;
            // $display("%h %h %h", to_Cache_pc[0], input_ins, predict_pc);
        end
    end
end
endmodule