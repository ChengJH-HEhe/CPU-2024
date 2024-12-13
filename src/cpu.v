// RISCV32 CPU top module
// port modification allowed for debugging purposes

`include "const.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

// format name-receiver-sender

// Decoder

wire rdy_decoder_ifetcher, jump_decoder_ifetcher;
wire [31 : 0] pc_decoder_ifetcher, ins_decoder_ifetcher;
wire stall_ifetcher_decoder, clear_ifetcher_decoder;
wire [31 : 0] addr_ifetcher_decoder;

// icache<->ifetcher
wire [31 : 0] input_ins_ifetcher_icache, cache_pc_icache_ifetcher;
wire rdy_ifetcher_icache, fetch_able_icache_ifetcher;
// b-predictor<->ifetcher
wire [31 : 0] branch_ins_bp_ifetcher, branch_pc_bp_ifetcher, predict_pc_ifetcher_bp;
wire pred_jump_ifetcher_bp;
// ROB_jalr <-> ifetcher
wire jalr_reset_ifetcher_rob;
wire [31 : 0] jalr_pc_ifetcher_rob; 
// rob_bp
wire rdy_bp_rob, success_bp_rob;
wire [31 : 0] ins_pc_bp_rob;

wire rdy_decoder_rob, full_decoder_rob;
wire [`ROB_WIDTH_BIT - 1: 0] del_dep_decoder_rob;
wire rob_tail_deccoder_rob;

wire valid_rob_decoder, rdy_rob_decoder;
wire [31 : 0] ins_value_rob_decoder;
wire [4 : 0] ins_rd_rob_decoder;
wire [`ROB_TYPE - 1:0] ins_type_rob_decoder;
wire [31 : 0] ins_addr_rob_decoder, ins_jpaddr_rob_decoder;

wire valid_rs_decoder;
wire [`RS_TYPE - 1 : 0] ins_type_rs_decoder;
wire [31 : 0] ins_rs1_rs_decoder, ins_rs2_rs_decoder, imm_rs_decoder;
wire is_qi_rs_decoder, is_qj_rs_decoder;
wire [4 : 0] qi_rs_decoder, qj_rs_decoder, rob_id_rs_decoder;

wire lsb_full_decoder_lsb, valid_lsb_decoder;
wire [`LSB_TYPE - 1 : 0] ins_type_lsb_decoder;
wire [31 : 0] ins_rs1_lsb_decoder, ins_rs2_lsb_decoder, imm_lsb_decoder;
wire is_qi_lsb_decoder, is_qj_lsb_decoder;
wire [4 : 0] qi_lsb_decoder, qj_lsb_decoder, rob_id_lsb_decoder;

wire [4:0] ask_id1_regf_decoder, ask_id2_regf_decoder;
wire [31:0] ret_val1_decoder_regf, ret_val2_decoder_regf;
wire dep1_decoder_regf, dep2_decoder_regf;
wire [`ROB_WIDTH_BIT - 1: 0] ret_rob_id1_decoder_regf, ret_rob_id2_decoder_regf;

Bpredictor bpredictor(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .input_ins(input_ins_ifetcher_icache),
  .input_pc(pc_decoder_ifetcher),
  .predict_jump(jump_decoder_ifetcher),
  .predict_pc(predict_pc_ifetcher_bp),
  .ROB_valid(valid_rob_decoder),
  .ins_pc(ins_pc_bp_rob),
  .success(success_bp_rob)
);

IFetcher ifetcher(
  .stall(stall_ifetcher_decoder),
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .input_ins(input_ins_ifetcher_icache),
  .input_ins_ready(rdy_ifetcher_icache),
  .to_Cache_pc(cache_pc_icache_ifetcher),
  .fetch_able(fetch_able_icache_ifetcher),
  .output_ins_ready(rdy_decoder_ifetcher),
  .output_ins(ins_decoder_ifetcher),
  .output_pc(pc_decoder_ifetcher),
  .output_jump(jump_decoder_ifetcher),
  .branch_ins(branch_ins_bp_ifetcher),
  .branch_pc(branch_pc_bp_ifetcher),
  .predict_jump(pred_jump_ifetcher_bp),
  .predict_pc(predict_pc_ifetcher_bp),
  .jalr_reset(jalr_reset_ifetcher_rob),
  .jalr_pc(jalr_pc_ifetcher_rob)
);

Decoder decoder(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .ins_ready(rdy_decoder_ifetcher),
  .ins(ins_decoder_ifetcher),
  .pc(pc_decoder_ifetcher),
  .pred_jump(jump_decoder_ifetcher),
  .IFetcher_stall(stall_ifetcher_decoder),
  .IFetcher_new_addr(addr_ifetcher_decoder),
  .IFetcher_clear(clear_ifetcher_decoder),
  .ROB_ready(rdy_decoder_rob),
  .ROB_del_Dep(del_dep_decoder_rob),
  .rob_full(full_decoder_rob),
  .ROB_inst_valid(valid_rob_decoder),
  .ROB_inst_ready(rdy_rob_decoder),
  .ROB_ins_value(ins_value_rob_decoder),
  .ROB_ins_rd(ins_rd_rob_decoder),
  .ROB_ins_Type(ins_type_rob_decoder),
  .ROB_ins_Addr(ins_addr_rob_decoder),
  .ROB_ins_jpAddr(ins_jpaddr_rob_decoder),
  .rs_full(valid_rs_decoder),
  .rob_tail(rob_tail_deccoder_rob),
  .RS_inst_valid(valid_rs_decoder),
  .RS_ins_Type(ins_type_rs_decoder),
  .RS_ins_rs1(ins_rs1_rs_decoder),
  .RS_ins_rs2(ins_rs2_rs_decoder),
  .RS_imm(imm_rs_decoder),
  .RS_is_Qi(is_qi_rs_decoder),
  .RS_is_Qj(is_qj_rs_decoder),
  .RS_Qi(qi_rs_decoder),
  .RS_Qj(qj_rs_decoder),
  .RS_rob_id(rob_id_rs_decoder),
  .lsb_full(lsb_full_decoder_lsb),
  .LSB_ins_valid(valid_lsb_decoder),
  .LSB_ins_Type(ins_type_lsb_decoder),
  .LSB_ins_rd(ins_rd_lsb_decoder),
  .LSB_ins_rs1(ins_rs1_lsb_decoder),
  .LSB_ins_rs2(ins_rs2_lsb_decoder),
  .LSB_is_Qi(is_qi_lsb_decoder),
  .LSB_is_Qj(is_qj_lsb_decoder),
  .LSB_Qi(qi_lsb_decoder),
  .LSB_Qj(qj_lsb_decoder),
  .LSB_rob_id(rob_id_lsb_decoder),
  .ask_reg_id1(ask_id1_regf_decoder),
  .ask_reg_id2(ask_id2_regf_decoder),
  .REGF_ret_val_id1(ret_val1_decoder_regf),
  .REGF_ret_val_id2(ret_val2_decoder_regf),
  .REGF_dep_rs1(dep1_decoder_regf),
  .REGF_dep_rs2(dep2_decoder_regf),
  .ret_rob_id1_decoder_regf(ret_rob_id1_decoder_regf),
  .ret_rob_id2_decoder_regf(ret_rob_id2_decoder_regf)
);

endmodule