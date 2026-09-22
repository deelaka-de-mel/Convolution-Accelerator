module dual_port_mem_convolution #(
    parameter IMAGE_WIDTH = 64,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 12//image
)(
    input  logic                   clk,
    input  logic                   reset,

    input  logic pixel_valid,

    // 3x3 window output
    output logic [DATA_WIDTH-1:0] window [0:2][0:2],

    output logic window_valid,

    // Port A - CPU side(image)
    input  logic [ADDR_WIDTH-1:0]  cpu_addr,
    input  logic [DATA_WIDTH-1:0]  cpu_wdata,
    input  logic                   cpu_we,
    output logic [DATA_WIDTH-1:0]  cpu_rdata,

    /* Port B - Accelerator side
    input  logic [ADDR_WIDTH-1:0]  acc_addr,
    input  logic [DATA_WIDTH-1:0]  acc_wdata,
    input  logic                   acc_we,
    output logic [DATA_WIDTH-1:0]  acc_rdata*/
);
    //line buffers
    logic [7:0] line_buffer0 [0:63];
    logic [7:0] line_buffer1 [0:63];
    logic [7:0] line_buffer2 [0:63];

    /* Pixel streams from three rows
    logic [DATA_WIDTH-1:0] row0_pixel;
    logic [DATA_WIDTH-1:0] row1_pixel;
    logic [DATA_WIDTH-1:0] row2_pixel;**/

    // Horizontal shift registers
    logic [DATA_WIDTH-1:0] shift0 [0:2];
    logic [DATA_WIDTH-1:0] shift1 [0:2];
    logic [DATA_WIDTH-1:0] shift2 [0:2];

    // Column counter
    logic [5:0] col;

    logic [DATA_WIDTH-1:0] memory [0:(1<<ADDR_WIDTH)-1]; //image

    always_ff @(posedge clk) begin

        // CPU port
        //image write
        if (cpu_we)
            memory[cpu_addr] <= cpu_wdata;

        //image read
        cpu_rdata <= memory[cpu_addr];

        //
        if (reset) begin

            col <= 0;
            window_valid <= 0;

            //hard coded for the first three rows
            for (int i = 0; i < 64; i++) begin
                line_buffer0[i] <= memory[i];
                line_buffer1[i] <= memory[64 + i];
                line_buffer2[i] <= memory[128 + i];
            end

            for (int i = 0; i < 3; i++) begin
                shift0[i] <= 0;
                shift1[i] <= 0;
                shift2[i] <= 0;
            end

        end else begin

            window_valid <= 0;

            if (pixel_valid) begin
                
                /*get new pixel range for shift register
                row0_pixel <= line_buffer0[col];
                row1_pixel <= line_buffer1[col];
                row2_pixel <= line_buffer2[col];*/

                // Shift row 0
                shift0[0] <= shift0[1];
                shift0[1] <= shift0[2];
                shift0[2] <= line_buffer0[col];

                // Shift row 1
                shift1[0] <= shift1[1];
                shift1[1] <= shift1[2];
                shift1[2] <= line_buffer1[col];

                // Shift row 2
                shift2[0] <= shift2[1];
                shift2[1] <= shift2[2];
                shift2[2] <= line_buffer2[col];

                // After receiving 3 pixels,
                // a complete 3x3 window exists
                if (col >= 2) begin

                    window[0][0] <= shift0[0];
                    window[0][1] <= shift0[1];
                    window[0][2] <= shift0[2];

                    window[1][0] <= shift1[0];
                    window[1][1] <= shift1[1];
                    window[1][2] <= shift1[2];

                    window[2][0] <= shift2[0];
                    window[2][1] <= shift2[1];
                    window[2][2] <= shift2[2];

                    window_valid <= 1;

                end

                // Move to next column
                if (col == IMAGE_WIDTH-1)
                    col <= 0;
                else
                    col <= col + 1;

            end
        end



        /* Accelerator port
        if (acc_we)
            memory[acc_addr] <= acc_wdata;

        acc_rdata <= memory[acc_addr];*/

    end

endmodule



/*module image_bram (
    input  logic        clk,

    // Write interface
    input  logic        wr_en,
    input  logic [11:0] wr_addr,     // 0 to 4095
    input  logic [7:0]  wr_data,

    // Read interface
    input  logic [11:0] rd_addr,
    output logic [7:0]  rd_data
);

    // 4096 locations × 8 bits
    logic [7:0] memory [0:4095];

    always_ff @(posedge clk) begin

        // Write image pixel
        if (wr_en)
            memory[wr_addr] <= wr_data;

        // Read image pixel
        rd_data <= memory[rd_addr];

    end

endmodule*/