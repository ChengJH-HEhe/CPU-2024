`include "const.v"

module ReorderBuffer #(
        parameter ROB_SIZE_BIT = `ROB_WIDTH_BIT
    ) (
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire					rdy_in,			// ready signal, pause cpu when low


        // from Decoder: ins info
        input wire inst_valid,
        input wire inst_ready,
        input wire [31 : 0] ins_value,
        input wire [4 : 0] ins_rd,
        input wire [`ROB_TYPE - 1 : 0] ins_Type, // 0: NOP, 1: rs-ALU, 2: lsb-MEM, 3: rs-BRANCH
        input wire [31 : 0] ins_Addr,
        input wire [31 : 0] ins_jpAddr,
        
        // to Decoder

        // newly add_dep
        output wire [4 : 0] rob_tail,
        output wire rob_full,
        
        // from RS execute end.
        input wire rs_is_set,
        input wire [ROB_SIZE_BIT - 1 : 0] rs_set_id,
        input wire [31 : 0] rs_set_val,
        // from LSB execute end
        input wire lsb_is_set,
        input wire lsb_is_set_val,
        input wire [ROB_SIZE_BIT - 1 : 0] lsb_set_id,
        input wire [31 : 0] lsb_set_val,

        // to RegFile commit.
        output wire [ROB_SIZE_BIT - 1 : 0] write_reg_id,
        output wire [31 : 0] write_val,
        output wire [`ROB_WIDTH_BIT - 1: 0] write_ROB_id,

        // to RegFile new tail.
        output wire [4: 0] new_reg_id,
        output wire [`ROB_WIDTH_BIT - 1: 0] new_ROB_id,
        
        // answer regFile question about dependency
        input wire [ROB_SIZE_BIT - 1 : 0] rs1_id,
        output wire rs1_ready,
        output wire [31 : 0] rs1_val,

        input wire [ROB_SIZE_BIT - 1 : 0] rs2_id,
        output wire rs2_ready,
        output wire [31 : 0] rs2_val,

        // actual jump pc ifetcher?
        output reg clear_flag,
        output reg [31:0] pc_fact,
        // (TODO) rs1, rs2, same as rd? 
        output wire ready_commit, // commit id
        output wire rob_head_l_or_s,
        output wire [4:0] rob_head,
        output wire [31:0] commit_tim,
        output reg real_commit
    );
    localparam ROB_SIZE = 1 << ROB_SIZE_BIT;
    reg [31 : 0] commit_times;

    assign commit_tim = commit_times;

    reg ready[0 : ROB_SIZE - 1];
    reg busy[0 : ROB_SIZE - 1];

    reg [31 : 0] value[0 : ROB_SIZE - 1];
    reg [4 : 0] rd[0 : ROB_SIZE - 1];
    reg [`ROB_TYPE - 1 : 0] insType[0 : ROB_SIZE - 1]; // 0: Rd, 1 Store, 2: Branch
    reg [31 : 0] insAddr[0 : ROB_SIZE - 1];
    reg [31 : 0] jpAddr[0 : ROB_SIZE - 1];

    reg [`ROB_WIDTH_BIT - 1 : 0] head, tail;

    

    assign rob_head = head;

    integer i, file;

    always @(posedge clk_in) begin
        real_commit <= 0;
        if (rst_in || (clear_flag && rdy_in)) begin
            clear_flag <= 0;
            if(rst_in) begin
                commit_times <= 0;
            end
            head <= 0;
            tail <= 0;
            pc_fact <= 0;
            for (i = 0; i < ROB_SIZE; i = i + 1) begin
                ready[i] <= 0;
                busy[i] <= 0;
                value[i] <= 0;
                rd[i] <= 0;
                insType[i] <= 0;
                insAddr[i] <= 0;
                jpAddr[i] <= 0;
            end
        end else if (!rdy_in) begin
        end else begin
            // work
            if(rs_is_set) begin
                ready[rs_set_id] <= 1;
                value[rs_set_id] <= rs_set_val;
                // if(commit_times > 6245) begin
                //     $display("commit %d head: %d tail: %d", commit_times, head, tail);
                //     for(i = head; i < tail; i = i + 1) begin
                //         $display("[%d]: pc=%d", i, insAddr[i]);
                //     end
                // end
            end 
            if(lsb_is_set) begin
                ready[lsb_set_id] <= 1;
                // $display("lsb_[%d] is ready", lsb_set_id);
                value[lsb_set_id] <= lsb_set_val;
            end
            // new inst , push tail
            if(inst_valid) begin
                // inst_valid, inst_ready, ins_value, ins_rd, ins_Type, ins_Addr, ins_jpAddr,
                tail <= tail + 1;
                busy[tail] <= 1;
                ready[tail] <= inst_ready;
                value[tail] <= ins_value;
                insAddr[tail] <= ins_Addr;
                jpAddr[tail] <= ins_jpAddr;
                insType[tail] <= ins_Type;
                rd[tail] <= ins_rd;
            end
            if(ready_commit) begin
                head <= head + 1;
                busy[head] <= 0;
                ready[head] <= 0;
                // TODO commit head TypeBr
                commit_times <= commit_times + 1;
                real_commit <= 1'b1;
                // if(commit_times % 10 == 0)
                    $display("commit %d head: %d tail: %d, pc : %d", commit_times, head, tail, insAddr[head]);
                // begin
                //     file = $fopen("debug.txt","a");
                //     $fwrite(file, "commit_%d id = [%d]: addr = [%h]\n", 
                //     commit_times, head, insAddr[head]);
                //     $fclose(file);
                //     // $display("commit_times %d head: %d tail: %d", commit_times, head, tail);
                //     // $display("[%d]: pc=%d ready:%b", head, insAddr[head],ready[head]);
                // end
                // output 
                if (insType[head] == `TypeBr) begin
                    // Br predict fail.
                    if (value[head][0] ^ jpAddr[head][0]) begin
                        // $display("pc=%h actu:%h, pred:%h", insAddr[head], value[head], jpAddr[head]);
                        pc_fact <= value[head];
                        clear_flag <= 1;
                    end
                end     
            end
            // if(commit_times >= 521) 
        end
    end
    // original full or newly add full
    assign rob_full = (head == tail && busy[head]) || (tail + 5'b1 == head && inst_valid && !ready[head]);
    // 
    assign rob_head_l_or_s = busy[head] && (insType[head] == `TypeLd || insType[head] == `TypeSt);
    // assign empty = head == tail && !busy[head];
    // to RegFile commit.
    wire ready_head = ready[head];
    assign ready_commit = busy[head] && ready_head && rdy_in;
    
    wire commit = busy[head] && ready_head && rdy_in && (insType[head] == `TypeRd || insType[head] == `TypeLd);
     // with lsb when commit ends, reset to zero
    assign write_reg_id = commit ? rd[head] : 0;
    assign write_val = commit ? value[head] : 0;
    assign write_ROB_id = commit ? head : 0;
    assign rob_tail = tail;
    
    // to RegFile new tail.
    wire new_element = rdy_in && inst_valid && (ins_Type == `TypeRd || ins_Type == `TypeLd);
    assign new_reg_id = new_element ? ins_rd : 0;
    assign new_ROB_id = new_element ? tail : 0;

    // answer RegFile dependency? send back correct value
    // TODO: new collected result.
    assign rs1_ready = ready[rs1_id] || (rs_is_set && rs1_id == rs_set_id) || (lsb_is_set_val && rs1_id == lsb_set_id) || (inst_valid && inst_ready && rs1_id == tail);
    assign rs1_val = ready[rs1_id]? value[rs1_id] : 
                    rs_is_set && rs1_id == rs_set_id ? rs_set_val : 
                    lsb_is_set_val && rs1_id == lsb_set_id ? lsb_set_val : ins_value;

    assign rs2_ready = ready[rs2_id] || (rs_is_set && rs2_id == rs_set_id) || (lsb_is_set_val && rs2_id == lsb_set_id) || (inst_valid && inst_ready && rs2_id == tail);
    assign rs2_val = ready[rs2_id]? value[rs2_id] : 
                    rs_is_set && rs2_id == rs_set_id ? rs_set_val : 
                    lsb_is_set && rs2_id == lsb_set_id ? lsb_set_val : ins_value;
endmodule
