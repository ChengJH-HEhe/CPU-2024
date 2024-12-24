`include "const.v"

// load or store > insFetch.

module MemCtrl (
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
    input  wire					rdy_in,			// ready signal, pause cpu when low
  // with ram
  output reg ram_type, // 1 load, 0 store,
  output reg [31 : 0] addr_ram,
  output reg [7 : 0] data_ram,
  input wire [7 : 0] data_ram_in,
  input wire io_buffer_full,

  // to load,store
  output reg lsb_val_ready, // mem_val valid
  output reg [31 : 0] lsb_val,

  input wire lsb_need, // store or load reg valid
  input wire [31 : 0] addr,
  input wire [31 : 0] data,
  input wire load_or_store,
  // op[1~0] 0,1,2, byte-width;
  // op[2] = !signed
  // op[3] isStore 
  input wire [3 : 0] op,

  // from/to ICache
  input wire iCache_need,
  input wire [31 : 0] ins_addr,
  output reg ins_ready,
  output reg [31 : 0] ins
);

// state: which byte.
reg [2:0] state, total;

// status : 0: idle, 1: load, 2: store, 3: fetch
//  4: stall (wait for lsb to respond)
reg [2:0] status;
always @(posedge clk_in) begin
  // case op 1,2,4
  if(rst_in) begin 
    state <= 0;
    status <= 0;
    total <= 0;
    ins <= 0;
    ins_ready <= 0;
    lsb_val_ready <= 0;
    lsb_val <= 0;
    ram_type <= 0;
    addr_ram <= 0;
    data_ram <= 0;
  end else if(~rdy_in) begin
  end else begin
    case(status)
      3'b000 :begin
        // next circle not available
        ins_ready <= 1'b0;
        lsb_val_ready <= 1'b0;
        state <= 3'b000;
        if(lsb_need) begin
          // load store prior.
          // load 1, store 2
          status <= op[3] ? 3'b010 : 3'b001;
          ram_type <= op[3];
          case(op[1:0]) 
            2'b00 : total <= 3'b001;
            2'b01 : total <= 3'b010;
            2'b10 : total <= 3'b100;
          endcase
          addr_ram <= addr;
          data_ram <= data;
        end else if(iCache_need) begin
          status <= 3'b011; // FETCH
          total <= 3'b100;
          state <= 3'b000;
          addr_ram <= ins_addr;
          data_ram <= 8'b0;
          ram_type <= 1'b0;
        end else begin
          status <= 3'b0;
          total <= 3'b0;
          addr_ram <= 32'b0;
          data_ram <= 8'b0;
          ram_type <= 1'b0;
        end
      end
      3'b001 :begin // load
        case(state)
          3'b001 :begin
            lsb_val[7:0] <= data_ram_in;
          end
          3'b010 :begin
            lsb_val[15:8] <= data_ram_in;
          end
          3'b011 :begin
            lsb_val[23:16] <= data_ram_in;
          end
          3'b100 :begin
            lsb_val[31:24] <= data_ram_in;
          end
        endcase
        ram_type <= 1'b0;
        if(state == total) begin
          lsb_val_ready <= 1'b1;
          status <= 3'b100;
          state <= 3'b000;
          addr_ram <= 32'b0;
          ram_type <= 1'b0;
          // process lsb_val
          if(~op[2]) begin // signed
            case(total)
              3'b001 :
                lsb_val[31:8] <= {24{lsb_val[7]}};
              3'b010 :
                lsb_val[31:16] <= {16{lsb_val[15]}};
            endcase
          end else begin
            case(total)
              3'b001 :
                lsb_val[31:8] <= 24'b0;
              3'b010 :
                lsb_val[31:16] <= 16'b0;
            endcase
          end

        end else begin
          state <= state + 1;
          addr_ram <= addr_ram + 1;
        end
      end
      3'b010 : begin // store
        ram_type <= 1'b1;
        if(state != total) begin
          state <= state + 1;
          addr_ram <= addr_ram + 1;  
          case(state)
            3'b001 :begin
              data_ram <= data[7:0];
            end
            3'b010 :begin
              data_ram <= data[15:8];
            end
            3'b011 :begin
              data_ram <= data[23:16];
            end
            3'b100 :begin
              data_ram <= data[31:24];
            end
          endcase
        end else begin
          lsb_val_ready <= 1'b1;
          status <= 3'b100; // STALL!
          state <= 3'b000;
          ram_type <= 1'b0;
        end
      end
      3'b011 : begin // FETCH
        ram_type <= 1'b0;
        case(state)
          3'b001: ins[7:0] <= data_ram_in;
          3'b010: ins[15:8] <= data_ram_in;
          3'b011: ins[23:16] <= data_ram_in;
          3'b100: ins[31:24] <= data_ram_in;
        endcase
        if(state == total) begin
          status <= 3'b100;
          ins_ready <= 1'b1;

          state <= 3'b000;
          total <= 3'b000;
          addr_ram <= 32'b0;
          ram_type <= 1'b0;
        end else begin
          state <= state + 1;
          addr_ram <= addr_ram + 1;
        end
      end
      3'b100 : begin // STALL
        // clear
        status <= 3'b000;
        ins_ready <= 1'b0;
        lsb_val_ready <= 1'b0;
      end
      default : begin
        status <= 3'b000;
      end
    endcase
  end
end

endmodule