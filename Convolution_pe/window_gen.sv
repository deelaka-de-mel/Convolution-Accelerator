module window_gen #(
    parameter PIXEL_WIDTH = 8,
    parameter IMG_WIDTH   = 512,
    parameter IMG_HEIGHT  = 512
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    pixel_valid,
    input  logic [PIXEL_WIDTH-1:0]  pixel_in,

    output logic [PIXEL_WIDTH-1:0]  window [0:8],
    output logic                    window_valid
);

    logic [PIXEL_WIDTH-1:0] row1_pixel, row0_pixel;

    line_buffer #(.WIDTH(PIXEL_WIDTH), .DEPTH(IMG_WIDTH)) lb0 ( // no output for 512 cycles
        .clk(clk), .rst(rst), .wr_en(pixel_valid),
        .data_in(pixel_in), .data_out(row1_pixel)
    );

    line_buffer #(.WIDTH(PIXEL_WIDTH), .DEPTH(IMG_WIDTH)) lb1 ( // no output for 512*2 cycles
        .clk(clk), .rst(rst), .wr_en(pixel_valid),
        .data_in(row1_pixel), .data_out(row0_pixel)
    );

    // 3-tap horizontal shift registers, one per row
    logic [PIXEL_WIDTH-1:0] tap_row0 [0:2];
    logic [PIXEL_WIDTH-1:0] tap_row1 [0:2];
    logic [PIXEL_WIDTH-1:0] tap_row2 [0:2];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < 3; i++) begin
                tap_row0[i] <= '0;
                tap_row1[i] <= '0;
                tap_row2[i] <= '0;
            end
        end else if (pixel_valid) begin
            tap_row0[2] <= tap_row0[1]; tap_row0[1] <= tap_row0[0]; tap_row0[0] <= row0_pixel;
            tap_row1[2] <= tap_row1[1]; tap_row1[1] <= tap_row1[0]; tap_row1[0] <= row1_pixel;
            tap_row2[2] <= tap_row2[1]; tap_row2[1] <= tap_row2[0]; tap_row2[0] <= pixel_in;
        end
    end

    // Pack into the 9-element window conv_pe expects
    assign window[0] = tap_row0[2]; assign window[1] = tap_row0[1]; assign window[2] = tap_row0[0];
    assign window[3] = tap_row1[2]; assign window[4] = tap_row1[1]; assign window[5] = tap_row1[0];
    assign window[6] = tap_row2[2]; assign window[7] = tap_row2[1]; assign window[8] = tap_row2[0];

    // Boundary tracking: only assert valid once a full 3x3 window exists
    logic [$clog2(IMG_WIDTH)-1:0]  col_cnt;
    logic [$clog2(IMG_HEIGHT)-1:0] row_cnt;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            col_cnt <= '0;
            row_cnt <= '0;
        end else if (pixel_valid) begin
            if (col_cnt == IMG_WIDTH-1) begin
                col_cnt <= '0;
                row_cnt <= (row_cnt == IMG_HEIGHT-1) ? '0 : row_cnt + 1'b1;
            end else begin
                col_cnt <= col_cnt + 1'b1;
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) window_valid <= 1'b0;
        else     window_valid <= pixel_valid && (col_cnt >= 2) && (row_cnt >= 2);
    end

endmodule