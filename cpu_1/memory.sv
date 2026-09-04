module memory (
  input  logic        clk,
  input  logic [7:0]  addr,
  input  logic [15:0] wdata,
  input  logic        wen,
  output logic [15:0] rdata
);
  logic [15:0] mem [256];

  always_ff @(posedge clk)
    if (wen) mem[addr] <= wdata;

  always_comb rdata = mem[addr];

endmodule
