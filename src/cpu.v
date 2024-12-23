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

wire rdy_decoder_ifetcher;
wire [31 : 0] pc_decoder_ifetcher, ins_decoder_ifetcher, predict_pc_decoder_ifetcher;
wire stall_ifetcher_decoder;

// icache<->ifetcher
wire [31 : 0] input_ins_ifetcher_icache, cache_pc_icache_ifetcher;
wire rdy_ifetcher_icache, fetch_able_icache_ifetcher;
// b-predictor<->ifetcher
wire [31 : 0] branch_ins_bp_ifetcher, branch_pc_bp_ifetcher, predict_pc_ifetcher_bp;

// ROB_jalr <-> ifetcher

// rob_bp pc, ins

// rob<>decoder
wire full_decoder_rob;
wire [`ROB_WIDTH_BIT - 1: 0] del_dep_decoder_rob;
wire valid_rob_decoder, rdy_rob_decoder;
wire [31 : 0] ins_value_rob_decoder;
wire [4 : 0] ins_rd_rob_decoder;
wire [`ROB_TYPE - 1:0] ins_type_rob_decoder;
wire [31 : 0] ins_addr_rob_decoder, ins_jpaddr_rob_decoder;

// rob<>lsb
wire lsb_ready_public;
wire [4:0] lsb_rob_id_public;
wire [31:0] lsb_val_public;

// rob<>regf
wire [`ROB_WIDTH_BIT - 1 : 0] write_ROB_id_regf_rob, write_reg_id_regf_rob;
wire [31 : 0] write_val_regf_rob;
wire [4 : 0] new_reg_id_regf_rob, new_ROB_id_regf_rob;

wire [`ROB_WIDTH_BIT - 1: 0] rs1_id_rob_regf, rs2_id_rob_regf;
wire rs1_rdy_rob_regf, rs2_rdy_rob_regf;
wire [31 : 0] rs1_val_rob_regf, rs2_val_rob_regf;

// rob_public
wire clear_flag_rob_public;
wire [31:0] pc_fact_rob_public;

// rs_decoder
wire valid_rs_decoder;
wire [`RS_TYPE - 1 : 0] ins_type_rs_decoder;
wire [31 : 0] ins_rs1_rs_decoder, ins_rs2_rs_decoder, imm_rs_decoder;
wire is_qi_rs_decoder, is_qj_rs_decoder;
wire [4 : 0] qi_rs_decoder, qj_rs_decoder, rob_id_rs_decoder;

// rs<>alu

wire [6:0] alu_op_alu_rs;
wire [31:0] vi_alu_rs, vj_alu_rs, imm_alu_rs;
wire [4:0] rd_alu_rs;
wire [31:0] pc_alu_rs;

// lsb 
wire lsb_full_decoder_lsb, valid_lsb_decoder;
wire [`LSB_TYPE - 1 : 0] ins_type_lsb_decoder;
wire [31 : 0] ins_rs1_lsb_decoder, ins_rs2_lsb_decoder, imm_lsb_decoder;
wire is_qi_lsb_decoder, is_qj_lsb_decoder;
wire [4 : 0] qi_lsb_decoder, qj_lsb_decoder, rob_id_lsb_decoder;

// regf
wire [4:0] ask_id1_regf_decoder, ask_id2_regf_decoder;
wire [31:0] ret_val1_decoder_regf, ret_val2_decoder_regf;
wire dep1_decoder_regf, dep2_decoder_regf;
wire [`ROB_WIDTH_BIT - 1: 0] ret_rob_id1_decoder_regf, ret_rob_id2_decoder_regf;

// rs_public
wire rs_full_public, rs_ready_public;
wire [31 : 0] rs_val_public;
wire [4 : 0] rs_rob_id_public;

// Icache, MemCtrl
wire need_mem_memCtrl_Icache, mem_ins_ready_Icache_memCtrl;
wire [31 : 0] mem_addr_Icache_memCtrl, mem_ins_Icache_memCtrl;

// lsb<>MemCtrl
wire mem_ready_lsb_mCtrl;
wire [31 : 0] mem_val_lsb_mCtrl;
wire full_mem_mCtrl_lsb, l_or_s_mCtrl_lsb;
wire [31 : 0] addr_mCtrl_lsb, data_mCtrl_lsb;
wire [3 : 0] op_mCtrl_lsb;
wire rdy_commit_public;

wire clear_ifetcher_decoder;
wire [31:0] pc_ifetcher_decoder;

wire [31 : 0] pc_rs_decoder;
wire [31 : 0] ins_pc_ifetcher_icache;

LSB lsb(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .clear_flag(clear_flag_rob_public),
  .rs_ready(rs_ready_public),
  .rs_ROB_id(rs_rob_id_public),
  .rs_val(rs_val_public),
  .ready_commit(rdy_commit_public),
  .commit_id(write_ROB_id_regf_rob),
  .ins_valid(valid_lsb_decoder),
  .ins_Type(ins_type_lsb_decoder),
  .ins_value1(ins_rs1_lsb_decoder),
  .ins_rd(rob_id_lsb_decoder),
  .ins_value2(ins_rs2_lsb_decoder), 
  .is_Qi(is_qi_lsb_decoder),
  .is_Qj(is_qj_lsb_decoder),
  .Qi(qi_lsb_decoder),
  .Qj(qj_lsb_decoder),
  .imm(imm_lsb_decoder),
  .mem_ready(mem_ready_lsb_mCtrl),
  .mem_val(mem_val_lsb_mCtrl),
  .full_mem(full_mem_mCtrl_lsb),
  .addr(addr_mCtrl_lsb),
  .data(data_mCtrl_lsb),
  .load_or_store(l_or_s_mCtrl_lsb),
  .op(op_mCtrl_lsb),
  .lsb_ready(lsb_ready_public),
  .lsb_ROB_id(lsb_rob_id_public),
  .lsb_val(lsb_val_public),
  .lsb_full(lsb_full_decoder_lsb)
);

MemCtrl memCtrl (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .ram_type(mem_wr),
  .addr_ram(mem_a),
  .data_ram(mem_dout),
  .data_ram_in(mem_din),
  .io_buffer_full(io_buffer_full),
  .lsb_val_ready(mem_ready_lsb_mCtrl),
  .lsb_val(mem_val_lsb_mCtrl),
  .lsb_need(full_mem_mCtrl_lsb),
  .addr(addr_mCtrl_lsb),
  .data(data_mCtrl_lsb),
  .load_or_store(l_or_s_mCtrl_lsb),
  .op(op_mCtrl_lsb),
  .iCache_need(need_mem_memCtrl_Icache),
  .ins_addr(mem_addr_Icache_memCtrl),
  .ins_ready(mem_ins_ready_Icache_memCtrl),
  .ins(mem_ins_Icache_memCtrl)
);

ICache icache(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .need_mem(need_mem_memCtrl_Icache),
  .mem_addr(mem_addr_Icache_memCtrl),
  .mem_ins(mem_ins_Icache_memCtrl),
  .mem_ins_ready(mem_ins_ready_Icache_memCtrl),

  .fetch_able(fetch_able_icache_ifetcher),
  .input_pc(cache_pc_icache_ifetcher),
  .hit(rdy_ifetcher_icache),
  .hit_ins(input_ins_ifetcher_icache),
  .ins_pc(ins_pc_ifetcher_icache)
);

IFetcher ifetcher(
  .stall(stall_ifetcher_decoder),
  .jalr_clear(clear_ifetcher_decoder),
  .jalr_pc(pc_ifetcher_decoder),
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
  .branch_ins(branch_ins_bp_ifetcher),
  .branch_pc(branch_pc_bp_ifetcher),
  .predict_pc(predict_pc_ifetcher_bp),
  .predict_nxt_pc(predict_pc_decoder_ifetcher),
  .br_reset(clear_flag_rob_public),
  .br_pc(pc_fact_rob_public),
  .ins_pc(ins_pc_ifetcher_icache)
);



RS rs(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .clear_flag(clear_flag_rob_public),
  .inst_valid(valid_rs_decoder),
  .ins_Type(ins_type_rs_decoder),
  .ins_rs1(ins_rs1_rs_decoder),
  .ins_rs2(ins_rs2_rs_decoder),
  .is_Qi(is_qi_rs_decoder),
  .is_Qj(is_qj_rs_decoder),
  .Qi(qi_rs_decoder),
  .Qj(qj_rs_decoder),
  .Imm_in(imm_rs_decoder),
  .ROB_id(rob_id_rs_decoder),
  .Pc_in(pc_rs_decoder),

  .full(rs_full_public),
  // give to alu ready
  .alu_op(alu_op_alu_rs),
  .Vi(vi_alu_rs),
  .Vj(vj_alu_rs),
  .imm(imm_alu_rs),
  .rd(rd_alu_rs),
  .pc(pc_alu_rs),
  // broadcast
  .rs_ready(rs_ready_public),
  .rs_ROB_id(rs_rob_id_public),
  .rs_val(rs_val_public),
  .lsb_ready(lsb_ready_public),
  .lsb_rob_id(lsb_rob_id_public),
  .lsb_val(lsb_val_public)
);

ALU alu(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .alu_op(alu_op_alu_rs),
  .Vi(vi_alu_rs),
  .Vj(vj_alu_rs),
  .imm(imm_alu_rs),
  .rd_in(rd_alu_rs),
  .pc(pc_alu_rs),
  .valid(rs_ready_public),
  .rd_out(rs_rob_id_public),
  .res(rs_val_public)
);

ReorderBuffer rob(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .inst_valid(valid_rob_decoder),
  .inst_ready(rdy_rob_decoder),
  .ins_value(ins_value_rob_decoder),
  .ins_rd(ins_rd_rob_decoder),
  .ins_Type(ins_type_rob_decoder),
  .ins_Addr(ins_addr_rob_decoder),
  .ins_jpAddr(ins_jpaddr_rob_decoder),
  .rob_tail(del_dep_decoder_rob),
  .rob_full(full_decoder_rob),
  
  .rs_is_set(rs_ready_public),
  .rs_set_id(rs_rob_id_public),
  .rs_set_val(rs_val_public),

  .lsb_is_set(lsb_ready_public),
  .lsb_set_id(lsb_rob_id_public),
  .lsb_set_val(lsb_val_public),

  .ready_commit(rdy_commit_public),
  .write_ROB_id(write_ROB_id_regf_rob),

  .write_reg_id(write_reg_id_regf_rob),
  .write_val(write_val_regf_rob),
  .new_reg_id(new_reg_id_regf_rob),
  .new_ROB_id(new_ROB_id_regf_rob),
  .clear_flag(clear_flag_rob_public),
  .pc_fact(pc_fact_rob_public),
  .rs1_id(rs1_id_rob_regf),
  .rs2_id(rs2_id_rob_regf),
  .rs1_ready(rs1_rdy_rob_regf),
  .rs1_val(rs1_val_rob_regf),
  .rs2_ready(rs2_rdy_rob_regf),
  .rs2_val(rs2_val_rob_regf)

);

// outports wire

RegFile u_RegFile(
  .clk_in       	( clk_in        ),
  .rst_in       	( rst_in        ),
  .rdy_in       	( rdy_in        ),
  .clear_flag   	( clear_flag_rob_public    ),
  .ask_reg_id1  	( ask_id1_regf_decoder   ),
  .ask_reg_id2  	( ask_id2_regf_decoder   ),
  .ret_val_id1  	( ret_val1_decoder_regf   ),
  .ret_val_id2  	( ret_val2_decoder_regf   ),
  .dep_rs1      	( dep1_decoder_regf       ),
  .dep_rs2      	( dep2_decoder_regf       ),
  .ret_ROB_id1  	( ret_rob_id1_decoder_regf   ),
  .ret_ROB_id2  	( ret_rob_id2_decoder_regf   ),
  .new_reg_id   	( new_reg_id_regf_rob    ),
  .new_ROB_id   	( new_ROB_id_regf_rob    ),
  .write_reg_id 	( write_reg_id_regf_rob  ),
  .write_ROB_id 	( write_ROB_id_regf_rob  ),
  .write_val    	( write_val_regf_rob     ),
  .rs1_id       	( rs1_id_rob_regf        ),
  .rs1_ready    	( rs1_rdy_rob_regf     ),
  .rs1_val      	( rs1_val_rob_regf       ),
  .rs2_id       	( rs2_id_rob_regf        ),
  .rs2_ready    	( rs2_rdy_rob_regf     ),
  .rs2_val      	( rs2_val_rob_regf       )
);


Bpredictor bpredictor(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .input_ins(branch_ins_bp_ifetcher),
  .input_pc(branch_pc_bp_ifetcher),
  .predict_pc(predict_pc_ifetcher_bp),
  .ROB_valid(rdy_commit_public),
  .ins_pc(pc_fact_rob_public)
);

Decoder decoder(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .ins_ready(rdy_decoder_ifetcher),
  .ins(ins_decoder_ifetcher),
  .pc(pc_decoder_ifetcher),
  .predict_nxt_pc(predict_pc_decoder_ifetcher),
  .IFetcher_stall(stall_ifetcher_decoder),
  .IFetcher_new_addr(pc_ifetcher_decoder),
  .IFetcher_clear(clear_ifetcher_decoder),
  .rob_full(full_decoder_rob),
  .ROB_inst_valid(valid_rob_decoder),
  .ROB_inst_ready(rdy_rob_decoder),
  .ROB_ins_value(ins_value_rob_decoder),
  .ROB_ins_rd(ins_rd_rob_decoder),
  .ROB_ins_Type(ins_type_rob_decoder),
  .ROB_ins_Addr(ins_addr_rob_decoder),
  .ROB_ins_jpAddr(ins_jpaddr_rob_decoder),
  .rs_full(rs_full_public),
  .rob_tail(del_dep_decoder_rob),
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
  .RS_pc(pc_rs_decoder),

  .lsb_full(lsb_full_decoder_lsb),
  .LSB_ins_valid(valid_lsb_decoder),
  .LSB_ins_Type(ins_type_lsb_decoder),
  .LSB_ins_rd(rob_id_lsb_decoder),
  .LSB_ins_rs1(ins_rs1_lsb_decoder),
  .LSB_ins_rs2(ins_rs2_lsb_decoder),

  .LSB_is_Qi(is_qi_lsb_decoder),
  .LSB_is_Qj(is_qj_lsb_decoder),
  .LSB_Qi(qi_lsb_decoder),
  .LSB_Qj(qj_lsb_decoder),
  .LSB_imm(imm_lsb_decoder),
  .ask_reg_id1(ask_id1_regf_decoder),
  .ask_reg_id2(ask_id2_regf_decoder),
  .REGF_ret_val_id1(ret_val1_decoder_regf),
  .REGF_ret_val_id2(ret_val2_decoder_regf),
  .REGF_dep_rs1(dep1_decoder_regf),
  .REGF_dep_rs2(dep2_decoder_regf),
  .REGF_ret_ROB_id1(ret_rob_id1_decoder_regf),
  .REGF_ret_ROB_id2(ret_rob_id2_decoder_regf)
);

endmodule