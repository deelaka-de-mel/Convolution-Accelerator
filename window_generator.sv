module window_generator #(
    parameter IMAGE_WIDTH  = 256,
    parameter IMAGE_HEIGHT = 256,
    parameter DATA_WIDTH   = 8,
    parameter ADDR_WIDTH   = 18
)(
    input  logic clk,
    input  logic reset,
    input  logic start,

    // ============================================================
    // Interface to IMAGE RAM
    //
    // image_addr is presented in cycle N.
    // image_data is returned in cycle N+1.
    // ============================================================

    output logic [ADDR_WIDTH-1:0] image_addr,
    input  logic [DATA_WIDTH-1:0] image_data,

    // ============================================================
    // AXI4-Stream output
    // ============================================================

    output logic [9*DATA_WIDTH-1:0] m_axis_tdata,
    output logic                     m_axis_tvalid,
    input  logic                     m_axis_tready,
    output logic                     m_axis_tlast,

    // ============================================================
    // Done
    //
    // Goes high when the last window has been accepted and stays
    // high until the next start.
    // ============================================================

    output logic done
);

    localparam OUTPUT_WIDTH = IMAGE_WIDTH - 2;
    localparam OUTPUT_HEIGHT = IMAGE_HEIGHT - 2;

    // ============================================================
    // Output FIFO
    //
    // Windows are written into a small FIFO and the AXI output is
    // taken from the FIFO. A new pixel is only requested when the
    // FIFO has room for every window that might already be inside
    // the pipeline (PIPE_SLACK), so no window is ever lost when
    // m_axis_tready goes low.
    // ============================================================

    localparam FIFO_DEPTH = 16;
    localparam FIFO_AW    = 4;
    localparam PIPE_SLACK = 6;   // 5 pixels can be in flight + 1 spare

    // ============================================================
    // State machine
    // ============================================================

    typedef enum logic [2:0] {
        S_IDLE,
        S_RUN,
        S_FINISH
    } state_t;

    state_t state;

    // ============================================================
    // Image position
    // ============================================================

    logic [9:0] row;
    logic [9:0] col;

    // High while there are still image pixels to request
    logic       requesting;

    // A pixel is requested from image RAM in this cycle
    logic       pixel_request;

    // Position associated with image_data
    logic [9:0] pixel_row;
    logic [9:0] pixel_col;
    logic       pixel_valid;

    // ============================================================
    // Two line buffers
    //
    // line_buffer1 = previous row
    // line_buffer2 = row before previous row
    //
    // These infer M9K RAM (see the separate always_ff below).
    // ============================================================

    logic [DATA_WIDTH-1:0] line_buffer1 [0:IMAGE_WIDTH-1];
    logic [DATA_WIDTH-1:0] line_buffer2 [0:IMAGE_WIDTH-1];

    // Registered read addresses
    logic [9:0] line1_read_addr;
    logic [9:0] line2_read_addr;

    // Registered M9K outputs
    logic [DATA_WIDTH-1:0] line1_read_data;
    logic [DATA_WIDTH-1:0] line2_read_data;

    logic line_buffer_we;

    // ============================================================
    // Pipeline stage 1
    //
    // Image RAM -> this stage
    // ============================================================

    logic [DATA_WIDTH-1:0] pixel_s1;
    logic [9:0]            row_s1;
    logic [9:0]            col_s1;
    logic                  valid_s1;

    // ============================================================
    // Pipeline stage 2
    //
    // Line buffer outputs + current pixel
    // ============================================================

    logic [DATA_WIDTH-1:0] top_pixel_s2;
    logic [DATA_WIDTH-1:0] middle_pixel_s2;
    logic [DATA_WIDTH-1:0] bottom_pixel_s2;

    logic [9:0] row_s2;
    logic [9:0] col_s2;
    logic       valid_s2;

    // ============================================================
    // Horizontal shift registers (stage 3)
    // ============================================================

    logic [DATA_WIDTH-1:0] top_shift    [0:2];
    logic [DATA_WIDTH-1:0] middle_shift [0:2];
    logic [DATA_WIDTH-1:0] bottom_shift [0:2];

    // Position of the pixel now in top/middle/bottom_shift[2]
    logic [9:0] row_s3;
    logic [9:0] col_s3;
    logic       valid_s3;

    // ============================================================
    // Output FIFO signals
    // ============================================================

    logic [9*DATA_WIDTH:0]   fifo_mem [0:FIFO_DEPTH-1];   // {tlast, tdata}
    logic [FIFO_AW-1:0]      fifo_wr_ptr;
    logic [FIFO_AW-1:0]      fifo_rd_ptr;
    logic [FIFO_AW:0]        fifo_count;
    logic                    fifo_wr;
    logic                    fifo_rd;

    logic [9*DATA_WIDTH-1:0] window_data;
    logic                    window_last;

    // ============================================================
    // Generate image address
    //
    // This address is requested one cycle before image_data
    // arrives from the synchronous image RAM.
    // ============================================================

    always_comb begin
        image_addr = (row * IMAGE_WIDTH) + col;
    end

    // ============================================================
    // Request a pixel only if the FIFO can absorb everything that
    // is already in flight
    // ============================================================

    always_comb begin
        pixel_request = (state == S_RUN) &&
                        requesting &&
                        (fifo_count < FIFO_DEPTH - PIPE_SLACK);
    end

    // ============================================================
    // Window assembly
    //
    // Uses the shift registers AFTER they have been updated, so the
    // window covers columns col_s3-2, col_s3-1, col_s3.
    // ============================================================

    always_comb begin

        /*
         * The window is:
         *
         * [top_shift[0]    top_shift[1]    top_shift[2]]
         * [middle_shift[0] middle_shift[1] middle_shift[2]]
         * [bottom_shift[0] bottom_shift[1] bottom_shift[2]]
         */

        window_data = {
            top_shift[0],
            top_shift[1],
            top_shift[2],

            middle_shift[0],
            middle_shift[1],
            middle_shift[2],

            bottom_shift[0],
            bottom_shift[1],
            bottom_shift[2]
        };

        // Last window of the complete 510×510 output
        window_last = (row_s3 == IMAGE_HEIGHT-1) &&
                      (col_s3 == IMAGE_WIDTH-1);

        fifo_wr = (state == S_RUN) &&
                  valid_s3 &&
                  (row_s3 >= 2) &&
                  (col_s3 >= 2);

    end

    // ============================================================
    // AXI stream comes straight from the FIFO
    //
    // tdata/tlast stay stable while tvalid=1 and tready=0, as the
    // AXI rules require.
    // ============================================================

    always_comb begin
        m_axis_tvalid = (fifo_count != 0);
        {m_axis_tlast, m_axis_tdata} = fifo_mem[fifo_rd_ptr];
        fifo_rd = m_axis_tvalid && m_axis_tready;
    end

    // ============================================================
    // FIFO storage (no reset, contents are only read when valid)
    // ============================================================

    always_ff @(posedge clk) begin
        if (fifo_wr)
            fifo_mem[fifo_wr_ptr] <= {window_last, window_data};
    end

    // ============================================================
    // Line buffer M9Ks
    //
    // Kept in their own always_ff with no reset so that Quartus
    // infers M9K blocks.
    //
    // For the pixel in stage 1 at column c:
    //   line_buffer2[c] <= old line_buffer1[c]  (row r-1 moves down)
    //   line_buffer1[c] <= current pixel        (row r)
    // ============================================================

    always_comb begin
        line_buffer_we = (state == S_RUN) && valid_s1;
    end

    always_ff @(posedge clk) begin

        line1_read_data <= line_buffer1[line1_read_addr];
        line2_read_data <= line_buffer2[line2_read_addr];

        if (line_buffer_we) begin
            line_buffer1[col_s1] <= pixel_s1;
            line_buffer2[col_s1] <= line1_read_data;
        end

    end

    // ============================================================
    // Main sequential logic
    // ============================================================

    always_ff @(posedge clk) begin

        if (reset) begin

            state <= S_IDLE;

            row <= 0;
            col <= 0;
            requesting <= 0;

            pixel_row <= 0;
            pixel_col <= 0;
            pixel_valid <= 0;

            line1_read_addr <= 0;
            line2_read_addr <= 0;

            pixel_s1 <= 0;
            row_s1 <= 0;
            col_s1 <= 0;
            valid_s1 <= 0;

            top_pixel_s2 <= 0;
            middle_pixel_s2 <= 0;
            bottom_pixel_s2 <= 0;

            row_s2 <= 0;
            col_s2 <= 0;
            valid_s2 <= 0;

            top_shift[0] <= 0;
            top_shift[1] <= 0;
            top_shift[2] <= 0;

            middle_shift[0] <= 0;
            middle_shift[1] <= 0;
            middle_shift[2] <= 0;

            bottom_shift[0] <= 0;
            bottom_shift[1] <= 0;
            bottom_shift[2] <= 0;

            row_s3 <= 0;
            col_s3 <= 0;
            valid_s3 <= 0;

            fifo_wr_ptr <= 0;
            fifo_rd_ptr <= 0;
            fifo_count  <= 0;

            done <= 0;

        end
        else begin

            case (state)

                // ==================================================
                // IDLE
                // ==================================================

                S_IDLE: begin

                    if (start) begin

                        row <= 0;
                        col <= 0;
                        requesting <= 1'b1;

                        pixel_valid <= 1'b0;
                        valid_s1 <= 1'b0;
                        valid_s2 <= 1'b0;
                        valid_s3 <= 1'b0;

                        fifo_wr_ptr <= 0;
                        fifo_rd_ptr <= 0;
                        fifo_count  <= 0;

                        done <= 1'b0;

                        state <= S_RUN;

                    end

                end


                // ==================================================
                // RUN
                // ==================================================

                S_RUN: begin

                    // ------------------------------------------------
                    // Request the next pixel
                    //
                    // The image address, line-buffer read address and
                    // pixel position all move together, and only when
                    // a pixel is actually requested.
                    // ------------------------------------------------

                    if (pixel_request) begin

                        line1_read_addr <= col;
                        line2_read_addr <= col;

                        // Save position belonging to image_data
                        pixel_row <= row;
                        pixel_col <= col;
                        pixel_valid <= 1'b1;

                        // Advance image position
                        if (col == IMAGE_WIDTH-1) begin

                            col <= 0;

                            if (row == IMAGE_HEIGHT-1) begin
                                // Last pixel requested
                                requesting <= 1'b0;
                            end
                            else begin
                                row <= row + 1;
                            end

                        end
                        else begin

                            col <= col + 1;

                        end

                    end
                    else begin

                        pixel_valid <= 1'b0;

                    end


                    // ------------------------------------------------
                    // Stage 1: IMAGE RAM RESPONSE
                    //
                    // image_data corresponds to the image address
                    // requested during the previous clock.
                    // line1/2_read_data arrive in the same cycle.
                    // ------------------------------------------------

                    pixel_s1 <= image_data;

                    row_s1 <= pixel_row;
                    col_s1 <= pixel_col;

                    valid_s1 <= pixel_valid;


                    // ------------------------------------------------
                    // Stage 2
                    //
                    // Line-buffer data is now available.
                    // ------------------------------------------------

                    if (valid_s1) begin

                        top_pixel_s2    <= line2_read_data;
                        middle_pixel_s2 <= line1_read_data;
                        bottom_pixel_s2 <= pixel_s1;

                        row_s2 <= row_s1;
                        col_s2 <= col_s1;

                    end

                    valid_s2 <= valid_s1;


                    // ------------------------------------------------
                    // Stage 3: Horizontal shift registers
                    // ------------------------------------------------

                    if (valid_s2) begin

                        // Top row
                        top_shift[0] <= top_shift[1];
                        top_shift[1] <= top_shift[2];
                        top_shift[2] <= top_pixel_s2;

                        // Middle row
                        middle_shift[0] <= middle_shift[1];
                        middle_shift[1] <= middle_shift[2];
                        middle_shift[2] <= middle_pixel_s2;

                        // Bottom row
                        bottom_shift[0] <= bottom_shift[1];
                        bottom_shift[1] <= bottom_shift[2];
                        bottom_shift[2] <= bottom_pixel_s2;

                        row_s3 <= row_s2;
                        col_s3 <= col_s2;

                    end

                    valid_s3 <= valid_s2;


                    // ------------------------------------------------
                    // FIFO pointers
                    // ------------------------------------------------

                    if (fifo_wr)
                        fifo_wr_ptr <= fifo_wr_ptr + 1'b1;

                    if (fifo_rd)
                        fifo_rd_ptr <= fifo_rd_ptr + 1'b1;

                    fifo_count <= fifo_count + fifo_wr - fifo_rd;


                    // ------------------------------------------------
                    // AXI handshake
                    //
                    // The frame is finished when the window with
                    // TLAST is actually transferred.
                    // ------------------------------------------------

                    if (fifo_rd && m_axis_tlast) begin

                        done  <= 1'b1;
                        state <= S_FINISH;

                    end

                end


                // ==================================================
                // FINISH
                // ==================================================

                S_FINISH: begin

                    // Pipeline and FIFO are empty here.
                    // Return to IDLE so the next start is accepted.
                    // done stays high until then.

                    state <= S_IDLE;

                end

            endcase

        end

    end

endmodule