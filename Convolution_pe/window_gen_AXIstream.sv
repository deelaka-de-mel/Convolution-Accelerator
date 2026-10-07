module window_gen_AXIstream #(
    parameter PIXEL_WIDTH = 8,
    parameter IMG_WIDTH   = 64,
    parameter IMG_HEIGHT  = 64
)(
    input  logic                       clk,
    input  logic                       rst,

    // AXI-Stream slave: pixels in
    input  logic [PIXEL_WIDTH-1:0]     s_axis_tdata,
    input  logic                       s_axis_tvalid,
    output logic                       s_axis_tready,
    input  logic                       s_axis_tlast,   // unused for now

    // AXI-Stream master: 3x3 windows out
    output logic [9*PIXEL_WIDTH-1:0]   m_axis_tdata,
    output logic                       m_axis_tvalid,
    input  logic                       m_axis_tready,
    output logic                       m_axis_tlast
);

    // [1][2] handshake
    logic accept;
    assign s_axis_tready = !m_axis_tvalid || m_axis_tready;
    assign accept        = s_axis_tvalid && s_axis_tready;

    // line buffers: all advance only on accept
    logic [PIXEL_WIDTH-1:0] row1_pixel, row0_pixel;

    lineBuffer #(.WIDTH(PIXEL_WIDTH), .DEPTH(IMG_WIDTH)) lb0 (
        .clk(clk), .rst(rst), .wr_en(accept),
        .data_in(s_axis_tdata), .data_out(row1_pixel)
    );
    lineBuffer #(.WIDTH(PIXEL_WIDTH), .DEPTH(IMG_WIDTH-1)) lb1 (   // [4] one shorter
        .clk(clk), .rst(rst), .wr_en(accept),
        .data_in(row1_pixel), .data_out(row0_pixel)
    );

    // [4] registered input pixel, lines up with the line-buffer outputs
    logic [PIXEL_WIDTH-1:0] pix_d;

    // newest column: pixels n-2W, n-W, n
    logic [PIXEL_WIDTH-1:0] cur_r0, cur_r1, cur_r2;
    assign cur_r0 = row0_pixel;
    assign cur_r1 = row1_pixel;
    assign cur_r2 = pix_d;

    // older columns (1 and 2 columns back)
    logic [PIXEL_WIDTH-1:0] p1_r0, p1_r1, p1_r2, p2_r0, p2_r1, p2_r2;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pix_d <= '0;
            {p1_r0, p1_r1, p1_r2, p2_r0, p2_r1, p2_r2} <= '0;
        end else if (accept) begin
            pix_d <= s_axis_tdata;
            p1_r0 <= cur_r0;  p2_r0 <= p1_r0;
            p1_r1 <= cur_r1;  p2_r1 <= p1_r1;
            p1_r2 <= cur_r2;  p2_r2 <= p1_r2;
        end
    end

    // pack: window[0] (top-left) in the LSBs, window[8] (bottom-right) in the MSBs
    assign m_axis_tdata = { cur_r2, p1_r2, p2_r2,
                            cur_r1, p1_r1, p2_r1,
                            cur_r0, p1_r0, p2_r0 };

    // position tracking (only moves on accept)
    logic [$clog2(IMG_WIDTH)-1:0]  col_cnt;
    logic [$clog2(IMG_HEIGHT)-1:0] row_cnt;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            col_cnt <= '0;
            row_cnt <= '0;
        end else if (accept) begin
            if (col_cnt == IMG_WIDTH-1) begin
                col_cnt <= '0;
                row_cnt <= (row_cnt == IMG_HEIGHT-1) ? '0 : row_cnt + 1'b1;
            end else
                col_cnt <= col_cnt + 1'b1;
        end
    end

    // [3][5] output valid/last: update only when our slot is free or being freed
    logic last_pixel;
    assign last_pixel = (col_cnt == IMG_WIDTH-1) && (row_cnt == IMG_HEIGHT-1);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else if (s_axis_tready) begin
            m_axis_tvalid <= accept && (col_cnt >= 2) && (row_cnt >= 2);
            m_axis_tlast  <= accept && last_pixel;
        end
    end

endmodule