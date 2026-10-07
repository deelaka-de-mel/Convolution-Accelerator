module conv_core #(
    parameter int FIFO_DEPTH        = 32,
    parameter int ALMOST_FULL_LEVEL = 20
)(
    input  logic               clk,
    input  logic               rst,

    input  logic signed [71:0] weights_flat,   // static kernel for now

    // input stream (slave)
    input  logic [71:0]        s_data,
    input  logic               s_valid,
    output logic               s_ready,
    input  logic               s_last,

    // output stream (master)
    output logic [7:0]         m_data,
    output logic               m_valid,
    input  logic               m_ready,
    output logic               m_last
);

    // ---------------- PE ----------------
    logic [7:0] pe_data;
    logic       pe_valid, pe_last;
    logic       pe_in_valid;

    logic       fifo_full, fifo_empty, fifo_almost_full;
    logic [8:0] fifo_rd_data;
    logic       fifo_rd_en;

    // accept a beat only if the FIFO can still absorb everything in flight
    assign s_ready     = ~fifo_almost_full;
    assign pe_in_valid = s_valid & s_ready;

    conv_pe u_pe (
        .clk          (clk),
        .rst          (rst),
        .input_valid  (pe_in_valid),
        .input_last   (s_last & pe_in_valid),
        .window_flat  (s_data),
        .weights_flat (weights_flat),
        .result_out   (pe_data),
        .output_valid (pe_valid),
        .output_last  (pe_last)
    );

    // ---------------- output FIFO ----------------
    sync_fifo #(
        .DATA_WIDTH        (9),
        .DEPTH             (FIFO_DEPTH),
        .ALMOST_FULL_LEVEL (ALMOST_FULL_LEVEL)
    ) u_fifo (
        .clk         (clk),
        .rst         (rst),
        .wr_en       (pe_valid),
        .wr_data     ({pe_last, pe_data}),
        .rd_en       (fifo_rd_en),
        .rd_data     (fifo_rd_data),
        .full        (fifo_full),
        .empty       (fifo_empty),
        .almost_full (fifo_almost_full)
    );

    assign m_valid    = ~fifo_empty;
    assign m_data     = fifo_rd_data[7:0];
    assign m_last     = fifo_rd_data[8];
    assign fifo_rd_en = m_valid & m_ready;

    // sim-only safety net: the headroom math should make this impossible
    // synthesis translate_off
    always_ff @(posedge clk)
        if (!rst && pe_valid && fifo_full)
            $error("conv_core: FIFO overflow - increase headroom");
    // synthesis translate_on

endmodule