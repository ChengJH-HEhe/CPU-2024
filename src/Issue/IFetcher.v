`include "const.v"

module IFetcher (
    input wire stall, // ROB/RS/LSB
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
    input wire jalr_reset,
    input wire [31 : 0] jalr_pc
);

localparam JAL = 7'b1101111;

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
    end else if(jalr_reset) begin
        fetch_able <= 1'b0;
        output_ins_ready <= 1'b0;
        to_Cache_pc <= 1'b0;
        pc <= jalr_pc;
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
            pc <= predict_pc; // next_circle
            output_ins <= input_ins;
            output_ins_ready <= 1'b1;

            // NEXT FETCH CIRCLE (PC)
            output_pc <= pc;
            predict_nxt_pc <= predict_pc;

            state <= 1'b0;
        end
    end
end
endmodule