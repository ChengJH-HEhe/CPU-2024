`include "const.v"

module LSB #(
  parameter LSB_SIZE_BIT = `LSB_WIDTH_BIT,
  parameter LSB_TYPE_BIT = `LSB_TYPE
) (
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
  input  wire					        rdy_in,			// ready signal, pause cpu when low
  input  wire clear_flag, // clear all data in LSB

  // from RS
  input wire rs_ready,
  input wire [4:0] rs_ROB_id,
  input wire [31:0] rs_val,

  // from ROB
  input wire ready_commit,
  input wire [4:0] commit_id,
  
  // receive from Decoder (ins_info)
  
  input wire ins_valid,
  input wire [LSB_TYPE_BIT - 1 : 0] ins_Type, // b,h,w / s,l 
  input wire [31 : 0] ins_value1,
  input wire [4 : 0] ins_rd, // rob_id,
  input wire [31 : 0] ins_value2,
  input wire is_Qi,
  input wire is_Qj,
  input wire [4 : 0] Qi,
  input wire [4 : 0] Qj,
  input wire [31 : 0] imm,

  // from & to memoryController
  input wire mem_ready, // mem_val valid
  input wire [31 : 0] mem_val,

  output reg full_mem, // store or load reg valid
  output reg [31 : 0] addr,
  output reg [31 : 0] data,
  output reg load_or_store,
  output reg [3 : 0] op,

  output reg lsb_ready, // val is valid
  output reg [4 : 0] lsb_ROB_id,
  output reg [31 : 0] lsb_val,
  output wire lsb_full
);
localparam LSB_SIZE = 1 << LSB_SIZE_BIT;
reg [LSB_SIZE_BIT - 1 : 0] head, tail;
reg [1 : 0] ticker;
wire is_Qi_, is_Qj_;
wire [4: 0] Qi_, Qj_;
wire [31: 0] Vi_, Vj_;
wire full;

assign full = head == tail + 1;
assign lsb_full = full;

// determine input Qi 
assign is_Qi_ = is_Qi && (!lsb_ready || Qi != lsb_ROB_id) && (!rs_ready || Qi != rs_ROB_id);
assign is_Qj_ = is_Qj && (!lsb_ready || Qj != lsb_ROB_id) && (!rs_ready || Qj != rs_ROB_id); 
assign Qi_ = is_Qi ? Qi : 0;
assign Qj_ = is_Qj ? Qj : 0;

// determine input Vi, Vj
assign Vi_ = lsb_ready && Qi == lsb_ROB_id ? lsb_val : 
            rs_ready && Qi == rs_ROB_id ? rs_val : 
            ins_value1;
assign Vj_ = lsb_ready && Qj == lsb_ROB_id ? lsb_val : 
            rs_ready && Qj == rs_ROB_id ? rs_val : 
            ins_value2;

reg valid[(1 << LSB_SIZE_BIT) - 1 : 0]; // exist elements
reg [LSB_TYPE_BIT - 1 : 0] Type[(1 << LSB_SIZE_BIT) - 1 : 0]; 
// b,h,w / s,l 
reg [31 : 0] value1[(1 << LSB_SIZE_BIT) - 1 : 0];
reg [4 : 0] rd[(1 << LSB_SIZE_BIT) - 1 : 0];
reg [31 : 0] value2[(1 << LSB_SIZE_BIT) - 1 : 0];
reg _Qi[(1 << LSB_SIZE_BIT) - 1 : 0];
reg _Qj[(1 << LSB_SIZE_BIT) - 1 : 0];
reg [4 : 0] lsb_Qi[(1 << LSB_SIZE_BIT) - 1 : 0];
reg [4 : 0] lsb_Qj[(1 << LSB_SIZE_BIT) - 1 : 0];
reg [31 : 0] lsb_imm[(1 << LSB_SIZE_BIT) - 1 : 0];

integer i;
always @(posedge clk_in) begin
  if (rst_in || clear_flag) begin
    head <= 0;
    tail <= 0;
    ticker <= 2'b00;
    full_mem <= 0;
    addr <= 0;
    data <= 0;
    load_or_store <= 0;
    op <= 0;
    lsb_ready <= 0;
    lsb_ROB_id <= 0;
    lsb_val <= 0;
    for (i = 0; i < (1 << LSB_SIZE_BIT); i = i + 1) begin
      Type[i] <= 0;
      value1[i] <= 0;
      rd[i] <= 0;
      value2[i] <= 0;
      _Qi[i] <= 0;
      _Qj[i] <= 0;
      lsb_Qi[i] <= 0;
      lsb_Qj[i] <= 0;
      lsb_imm[i] <= 0;
    end
  end else if(!rdy_in) begin
  end else begin
    // commit head
    case(ticker) // 2'b00 : wait; 2'b01: store; 2'b10: load
      2'b00: begin
        lsb_ready <= 0;
        // head is ready to execute.
        if (valid[head] && _Qi[head] == 0 && _Qj[head] == 0 && ready_commit && commit_id == rd[head]) begin
            full_mem <= 1; // to mem is full.
            head <= head + 1;
            addr <= value1[head] + lsb_imm[head];
            data <= value2[head];
            valid[head] <= 0;
            op <= (Type[head] >= `LB && Type[head] <= `LHU)? 1 : 2;
            ticker <= (Type[head] >= `LB && Type[head] <= `LHU)? 1 : 2;
            lsb_ROB_id <= commit_id;
        end
      end
      2'b01: begin // LOAD
        if (mem_ready) begin
          // head op returns
          // result ready
          lsb_ready <= 1;
          lsb_val <= mem_val;
          full_mem <= 0;
          ticker <= 2'b00;
        end else begin
          lsb_ready <= 0; // insurance
        end
      end
      2'b10: begin // STORE
        if (mem_ready) begin
          // head op returns
          // result ready
          lsb_ready <= 1;
          lsb_val <= 0;
          full_mem <= 0;
          ticker <= 2'b00;
        end else begin
          lsb_ready <= 0; // insurance
        end
      end
    endcase
    // push tail
    if(ins_valid) begin
      tail <= tail + 1;
      valid[tail] <= 1; // exist elements
      Type[tail] <= ins_Type; 
      // b,h,w / s,l 
      value1[tail] <= Vi_;
      rd[tail] <= ins_rd;
      value2[tail] <= Vj_;
      _Qi[tail] <= is_Qi_;
      _Qj[tail] <= is_Qj_;
      lsb_Qi[tail] <= Qi_;
      lsb_Qj[tail] <= Qj_;
      lsb_imm[tail] <= imm;
    end
    // delete dependency
    if (rs_ready) begin // result ok
      // delete correspondant dependency 
      for (i = 0; i < LSB_SIZE; i = i + 1) begin 
        if (lsb_Qi[i] == rs_ROB_id) begin
          value1[i] <= rs_val;
          lsb_Qi[i] <= 0;
          _Qi[i] <= 0;
        end
        if (lsb_Qj[i] == rs_ROB_id) begin
          value2[i] <= rs_val;
          lsb_Qj[i] <= 0;
          _Qj[i] <= 0;
        end
      end 
    end
    if (lsb_ready) begin
      for (i = 0; i < LSB_SIZE; i = i + 1) begin 
        if (lsb_Qi[i] == lsb_ROB_id) begin
          value1[i] <= rs_val;
          lsb_Qi[i] <= 0;
          _Qi[i] <= 0;
        end
        if (lsb_Qj[i] == lsb_ROB_id) begin
          value2[i] <= rs_val;
          lsb_Qj[i] <= 0;
          _Qj[i] <= 0;
        end
      end
    end
  end
end

endmodule