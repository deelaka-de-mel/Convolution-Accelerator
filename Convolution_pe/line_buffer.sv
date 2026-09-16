module line_buffer #(
    parameter IMAGE_WIDTH = 512;
)(
    input logic i_rd_data,  // goes high when someone wants to read data, 3 pixels are read.
    input logic i_clk,
    input logic i_rst,
    input logic i_data_valid,   // goes high if the input data is valid
    input  logic [7:0] i_data,  // data or pixel coming from memory
    output logic [7:0] o_data [0:2], // output 3 pixels 
    output logic row_done
);

    logic [7:0] line [IMAGE_WIDTH-1:0] ; // line buffer
    logic [$clog2(IMAGE_WIDTH)-1:0] wr_ptr;
    logic [$clog2(IMAGE_WIDTH)-1:0] rd_ptr;

// write logic
    always @(posedge i_clk) begin
        if (i_rst) begin
            for (int i=0 ; i<512; i++) line[i] <= 0;
            wr_ptr <='d0;

        end

        else begin
            if (i_data_valid) begin
            line[wr_ptr] <= i_data;
            wr_ptr <= wr_ptr +'d1;
            end

        end
    end
//read logic
    always @(posedge i_clk) begin
        if (i_rst) begin
            rd_ptr <='d0;
        end
        else begin
            if (i_rd_data) begin
                rd_ptr <= rd_ptr +1;
            end
        end
    end

    always_comb begin
        for (int i=0 ; i<3 ; i++) begin
            o_data[i] = line[rd_ptr+i];
        end
    end

endmodule