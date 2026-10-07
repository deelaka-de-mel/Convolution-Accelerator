module quantizer #(
    parameter int IN_W = 20,
    parameter int OUT_W = 8,
    parameter int SHIFT = 4  // make this a runtime input later. depends on the kernel loaded.
)(
    input logic clk,
    input logic rst,
    input logic in_valid,
    input logic in_last,
    input logic signed [IN_W-1: 0] data_in,

    output logic [OUT_W-1:0] data_out,
    output logic out_valid,
    output logic out_last
);

    logic signed [IN_W : 0] rounded_data;
    localparam int rounding_const = (SHIFT==0) ? 0 : 1 <<< (SHIFT-1);

    always_comb begin 
        rounded_data = $signed({data_in[IN_W-1] , data_in}) + $signed(rounding_const);
    end

    logic signed [IN_W:0] reg_rounded_data;

    always_ff @(posedge clk) begin : rounded_result
        reg_rounded_data <= rounded_data;
    end

    logic signed [IN_W:0] shifted_data;

    always_comb begin
        shifted_data = reg_rounded_data >>> SHIFT;
    end

    localparam int MAX_VALUE = (1<<<OUT_W) - 1;
    logic [OUT_W-1:0] clamped_data;

    always_comb begin
        if (shifted_data[IN_W]) clamped_data = 0;
        else if (shifted_data > MAX_VALUE) clamped_data = OUT_W'(MAX_VALUE);
        else clamped_data = shifted_data[OUT_W-1:0];
    end

    always_ff @(posedge clk) begin
        data_out <= clamped_data;
        
    end

    logic [1:0] valid_pipe;
    logic [1:0] last_pipe;

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_pipe <= 0;
        end
        else begin
            valid_pipe[0] <=in_valid;
            valid_pipe[1] <= valid_pipe[0];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            last_pipe <= 0;
        end
        else begin
            last_pipe[0] <=in_last;
            last_pipe[1] <= last_pipe[0];
        end
    end

    assign out_valid = valid_pipe[1];
    assign out_last = last_pipe[1];

endmodule