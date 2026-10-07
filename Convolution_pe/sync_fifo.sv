module sync_fifo #(
    parameter int DATA_WIDTH        = 8,
    parameter int DEPTH             = 32,   // must be a power of 2
    parameter int ALMOST_FULL_LEVEL = 20
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,   // FWFT: valid whenever !empty
    output logic                  full,
    output logic                  empty,
    output logic                  almost_full
);
    localparam int N = $clog2(DEPTH);

    logic [N:0]            wr_ptr, rd_ptr, count;
    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    logic                  do_wr, do_rd;

    assign do_wr = wr_en && !full;
    assign do_rd = rd_en && !empty;

    // pointers
    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (do_wr) wr_ptr <= wr_ptr + 1'b1;
            if (do_rd) rd_ptr <= rd_ptr + 1'b1;
        end
    end

    // storage (no reset)
    always_ff @(posedge clk)
        if (do_wr) memory[wr_ptr[N-1:0]] <= wr_data;

    assign rd_data = memory[rd_ptr[N-1:0]];

    // status
    assign count       = wr_ptr - rd_ptr;
    assign empty       = (wr_ptr == rd_ptr);
    assign full        = (wr_ptr[N-1:0] == rd_ptr[N-1:0]) && (wr_ptr[N] != rd_ptr[N]);
    assign almost_full = (count >= ALMOST_FULL_LEVEL);

endmodule