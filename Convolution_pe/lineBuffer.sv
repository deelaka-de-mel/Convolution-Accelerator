module lineBuffer #(
    parameter WIDTH = 8,
    parameter DEPTH = 512
)(
    input  logic             clk,
    input  logic             rst,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH)-1:0] ptr;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ptr      <= '0;
            data_out <= '0;
        end else if (wr_en) begin
            data_out <= mem[ptr];      // read OLD value first (BRAM-friendly)
            mem[ptr] <= data_in;       // then overwrite with new pixel
            ptr      <= (ptr == DEPTH-1) ? '0 : ptr + 1'b1;
        end
    end
    
endmodule