`include "const.v"

module IFetcher (
    input wire stall, // pause
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
    input  wire					rdy_in,			// ready signal, pause cpu when low

    input wire [31 : 0] input_ins,
    input wire input_ins_ready,
    
    // icache
    output reg [31 : 0] to_Cache_pc,
    output reg fetch_able,

    // decoder ok to receive?(no need)

    // Decoder
    output reg output_ins_ready,
    output reg [31 : 0] output_ins,
    output reg [31 : 0] output_pc,
    output reg [31 : 0] predict_nxt_pc,
    // b-predictor
    output wire [31 : 0] branch_ins,
    output wire [31 : 0] branch_pc,
    input wire [31 : 0] predict_pc,

    // ROB JALR
    input wire br_reset,
    input wire [31 : 0] br_pc
);

localparam JAL = 7'b1101111;
wire [20:1] immJ = {input_ins[31], input_ins[19:12], input_ins[20], input_ins[30:21], 1'b0};
reg state; // 0: IDLE, 1: BUSY waiting
reg [31 : 0] pc;
assign branch_ins = input_ins;
assign branch_pc = pc;

always @(posedge clk_in) begin
    if(rst_in) begin
        to_Cache_pc <= 32'b0;
        fetch_able <= 1'b0;
        output_ins <= 32'b0;
        output_ins_ready <= 1'b0;
        output_pc <= 32'b0;

        pc <= 32'b0;
        state <= 1'b0;

    end else if(~rdy_in) begin
    end else if(br_reset) begin
        fetch_able <= 1'b0;
        output_ins_ready <= 1'b0;
        to_Cache_pc <= 1'b0;
        pc <= br_pc;
        state <= 1'b0;
    end else if(state == 1'b0) begin
        // ready to fetch
        if(stall) begin
            fetch_able <= 1'b0;
            output_ins_ready <= 1'b0;
            to_Cache_pc <= 1'b0;
        end else begin
            to_Cache_pc <= pc;
            fetch_able <= 1'b1;
            state <= 1'b1;
            output_ins_ready <= 1'b0;
            output_pc <= 0;
        end
    end else begin
        // is waiting
        if(~stall && input_ins_ready) begin
            // instruction ready, special : JAL
            if(input_ins[6:0] == JAL) begin
                pc <= pc + immJ;
                predict_nxt_pc <= pc + immJ;
            end else begin
                pc <= predict_pc; // next_circle
                predict_nxt_pc <= predict_pc;
            end
            output_ins <= input_ins;
            output_ins_ready <= 1'b1;

            // NEXT FETCH CIRCLE (PC)
            output_pc <= pc;
            state <= 1'b0;
        end
    end
end
endmodule