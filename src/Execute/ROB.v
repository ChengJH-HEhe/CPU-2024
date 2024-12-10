`include "const.v"

module ReorderBuffer #(
        parameter ROB_SIZE_BIT = `ROB_WIDTH_BIT
    ) (
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire					rdy_in,			// ready signal, pause cpu when low
        input  wire                 clear,


        // from Decoder: ins info
        input wire inst_valid,
        input wire inst_ready,
        input wire [31 : 0] ins_value,
        input wire [4 : 0] ins_rd,
        input wire [`ROB_TYPE - 1 : 0] ins_Type, // 0: NOP, 1: rs-ALU, 2: lsb-MEM, 3: rs-BRANCH
        input wire [31 : 0] ins_Addr,
        input wire [31 : 0] ins_jpAddr,

        // from RS execute end.
        input wire rs_is_set,
        input wire [ROB_SIZE_BIT - 1 : 0] rs_set_id,
        input wire [31 : 0] rs_set_val,
        // from LSB execute end
        input wire lsb_is_set,
        input wire [ROB_SIZE_BIT - 1 : 0] lsb_set_id,
        input wire [31 : 0] lsb_set_val,
        // to Decoder 

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

        output reg clear_flag,
        // actual jump pc
        output reg [31:0] pc_fact

        // (TODO) rs1, rs2, same as rd? 
    );
    localparam ROB_SIZE = 1 << ROB_SIZE_BIT;
    localparam TypeRd = 2'b00;
    localparam TypeSt = 2'b01;
    localparam TypeBr = 2'b10;

    reg ready[0 : ROB_SIZE - 1];
    reg busy[0 : ROB_SIZE - 1];

    reg [31 : 0] value[0 : ROB_SIZE - 1];
    reg [4 : 0] rd[0 : ROB_SIZE - 1];
    reg [`ROB_TYPE - 1 : 0] insType[0 : ROB_SIZE - 1]; // 0: Rd, 1 Store, 2: Branch
    reg [31 : 0] insAddr[0 : ROB_SIZE - 1];
    reg [31 : 0] jpAddr[0 : ROB_SIZE - 1];

    reg [`ROB_WIDTH_BIT - 1 : 0] head, tail;
    integer i;
    always @(posedge clk_in) begin
        if (rst_in || (clear && rdy_in)) begin
            clear_flag <= 0;
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
            end 
            if(lsb_is_set) begin
                ready[lsb_set_id] <= 1;
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
            if(busy[head] && ready[head]) begin
                head <= head + 1;
                busy[head] <= 0;
                ready[head] <= 0;
                // TODO commit head 
                if (insType[head] == TypeBr) begin
                    // Br predict fail.
                end     
            end
        end
    end
    // original full or newly add full
    assign full = (head == tail && busy[head]) || (tail + 5'b1 == head && inst_valid && !ready[head]);
    // 
    assign empty = head == tail && !busy[head];

    // to RegFile commit.
    wire commit = busy[head] && ready[head] && rdy_in && insType[head] == TypeRd;
    assign write_reg_id = commit ? rd[head] : 0;
    assign write_val = commit ? value[head] : 0;
    assign write_ROB_id = commit ? head : 0;

    // to RegFile new tail.
    wire new_element = rdy_in && inst_valid && ins_Type == TypeRd;
    assign new_reg_id = new_element ? ins_rd : 0;
    assign new_ROB_id = new_element ? tail : 0;

    // answer RegFile dependency? send back correct value
    assign rs1_ready = ready[rs1_id];
    assign rs1_val = value[rs1_id];

    assign rs1_ready = ready[rs1_id];
    assign rs1_val = value[rs1_id];
endmodule
