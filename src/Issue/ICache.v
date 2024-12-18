`include "const.v"

`define TAG_INTERVAL 17:11
`define SUB_INTERVAL 10:2
`define CACHE_INTERVAL 511:0

module ICache (
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
  input  wire					rdy_in,			// ready signal, pause cpu when low

  // MemCtrl 
  output reg need_mem,
  output reg [31 : 0] mem_addr,
  input wire [31 : 0] mem_ins,
  input wire mem_ins_ready,
  // Ifetcher
  input wire fetch_able,
  input wire [31 : 0] input_pc, 
  output wire hit,
  output wire [31 : 0] hit_ins

);

reg state;
reg[31 : 0] insCache[`CACHE_INTERVAL];
reg [`TAG_INTERVAL] tag[`CACHE_INTERVAL];
reg valid[`CACHE_INTERVAL];

wire ins_id = input_pc[`SUB_INTERVAL];

assign hit = fetch_able && valid[ins_id] && tag[ins_id] == input_pc[`TAG_INTERVAL] || mem_ins_ready && mem_addr == input_pc;
assign hit_ins = mem_ins_ready && mem_addr == input_pc ? mem_ins : insCache[ins_id];

integer i;
always @(posedge clk_in) begin
  if (rst_in) begin
    state <= 1'b0;
    need_mem <= 1'b0;
    mem_addr <= 0;
    for (i = 0; i < 512; i = i + 1) begin
      insCache[i] <= 0;
      tag[i] <= 0;
      valid[i] <= 0;
    end
  end
  else if(fetch_able) begin
    case (state)
      0: begin
        if (~hit) begin
          state <= 1;
          need_mem <= 1;
          mem_addr <= input_pc;
        end
      end
      1: begin
        if (mem_ins_ready) begin
          state <= 1'b0;
          need_mem <= 1'b0;
          insCache[ins_id] <= mem_ins;
          tag[ins_id] <= input_pc[`TAG_INTERVAL];
          valid[ins_id] <= 1;
        end
      end
    endcase
  end
end

endmodule