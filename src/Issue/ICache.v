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
  output wire [31 : 0] hit_ins,
  output wire [31 : 0] ins_pc

);

reg state;
reg[31 : 0] insCache[`CACHE_INTERVAL];
reg [`TAG_INTERVAL] tag[`CACHE_INTERVAL];
reg valid[`CACHE_INTERVAL];

wire [`SUB_INTERVAL] ins_id = input_pc[`SUB_INTERVAL];
wire [`TAG_INTERVAL] ins_tag = input_pc[`TAG_INTERVAL];

assign ins_pc = input_pc;
assign hit = fetch_able && ((valid[ins_id] && tag[ins_id] == ins_tag) || (mem_ins_ready && mem_addr == input_pc));
assign hit_ins = mem_ins_ready && mem_addr == input_pc ? mem_ins : insCache[ins_id];

wire mem_sub = mem_addr[`SUB_INTERVAL];
wire mem_tag = mem_addr[`TAG_INTERVAL];

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
    // if(ins_pc == 32'hcc)
    //   $display("[%d] hit=%d, valid=%d, tag=%d, ins_pc=%d", ins_pc, hit, ins_id, valid[ins_id], tag[ins_id], input_pc[`TAG_INTERVAL]);
    case (state)
      0: begin
        if (~hit) begin
          state <= 1;
          need_mem <= 1;
          mem_addr <= input_pc;
          $display("addr <= %d", input_pc);
        end
      end
      1: begin
        if (mem_ins_ready && mem_addr == ins_pc) begin
          state <= 1'b0;
          need_mem <= 1'b0;
          insCache[mem_sub] <= mem_ins;
          tag[mem_sub] <= mem_tag;
          valid[mem_sub] <= 1;
          mem_addr <= 0;
          $display("addr=%d,valid[%d]=1", ins_pc, mem_sub);
        end
      end
    endcase
  end
end

endmodule