/////////The Interface 
interface fifo_if(input logic clk, rst_n);
  logic w_en, r_en;
  logic [7:0] w_data;
  logic [7:0] r_data;
  logic full, empty;
endinterface

//////////The Design (DUT)
module fifo_dut (
  input  logic clk,
  input  logic rst_n,
  input  logic w_en,
  input  logic r_en,
  input  logic [7:0] w_data,
  output logic [7:0] r_data,
  output logic full,
  output logic empty
);

  parameter DEPTH = 16;
  logic [7:0] mem [0:DEPTH-1];
  logic [4:0] count; 
  logic [3:0] w_ptr, r_ptr;

  assign full  = (count == DEPTH);
  assign empty = (count == 0);
  assign r_data = mem[r_ptr]; 

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_ptr <= 0;
      r_ptr <= 0;
      count <= 0;
    end else begin
      case ({w_en && !full, r_en && !empty})
        2'b10: begin 
          mem[w_ptr] <= w_data;
          w_ptr <= w_ptr + 1;
          count <= count + 1;
        end
        2'b01: begin 
          r_ptr <= r_ptr + 1;
          count <= count - 1;
        end
        2'b11: begin 
          mem[w_ptr] <= w_data;
          w_ptr <= w_ptr + 1;
          r_ptr <= r_ptr + 1;
        end
      endcase
    end
  end
endmodule
