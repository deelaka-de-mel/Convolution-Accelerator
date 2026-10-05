module quantizer #(
    parameter int IN_W = 20,
    parameter int OUT_W = 8,
    parameter int SHIFT = 4  // make this a runtime input later. depends on the kernel loaded.
)(
    input logic clk,
    input logic rst,
    input logic in_valid,
    input logic signed [IN_W-1: 0] data_in,

    output logic [OUT_W-1:0] data_out,
    output logic out_valid
);

    logic signed [IN_W : 0] rounded_data;
    localparam int rounding_const = (SHIFT==0) ? 0 : 1 <<< (SHIFT-1);

    always_comb begin 
        rounded_data = $signed({data_in[IN_W-1] , data_in}) + $signed(rounding_const);
    end

    logic signed [IN_W:0] reg_rounded_data;

    always_ff @(posedge clk or posedge rst) begin : rounded_result
        if (rst) reg_rounded_data <=0;
        else begin
            reg_rounded_data <= rounded_data;
        end
    end

    logic signed [IN_W:0] shifted_data;

    always_comb begin
        shifted_data = reg_rounded_data >>> SHIFT;
    end

    localparam int MAX_VALUE = (1<<<OUT_W) - 1;
    logic [OUT_W-1:0] clamped_data;

    always_comb begin
        if (shifted_data[IN_W]) clamped_data = 0;
        else if (shifted_data > MAX_VALUE) clamped_data = MAX_VALUE[OUT_W-1:0];
        else clamped_data = shifted_data[OUT_W-1:0];
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) data_out <=0;
        else data_out <= clamped_data;
        
    end

    logic [1:0] valid_pipe;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_pipe <= 0;
        end
        else begin
            valid_pipe[0] <=in_valid;
            valid_pipe[1] <= valid_pipe[0];
        end
    end

    assign out_valid = valid_pipe[1];

endmodule