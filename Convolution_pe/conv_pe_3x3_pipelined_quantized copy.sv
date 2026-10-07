module conv_pe_3x3_pipelined_quantized (
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    input_valid,

    input  logic [71:0]              window_flat,
    input  logic signed [71:0]       weights_flat,
    input logic                      input_last,

    output logic [7:0]              result_out,
    output logic                    output_last
    output logic                    output_valid
);

    // Stage 0: Multiplication

    logic signed [15:0] product     [0:8];
    logic signed [15:0] product_reg [0:8];

    always_comb begin
        for (int i = 0; i < 9; i++) begin
            product[i] =
                $signed({1'b0, window_flat[8*i +: 8]}) * $signed(weights_flat[8*i +: 8]);
        end
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < 9; i++)
            product_reg[i] <= product[i];
    end


    // Stage 1: 9 -> 5


    logic signed [16:0] s1     [0:4];
    logic signed [16:0] s1_reg [0:4];

    always_comb begin
        s1[0] = $signed(product_reg[0]) +
                $signed(product_reg[1]);

        s1[1] = $signed(product_reg[2]) +
                $signed(product_reg[3]);

        s1[2] = $signed(product_reg[4]) +
                $signed(product_reg[5]);

        s1[3] = $signed(product_reg[6]) +
                $signed(product_reg[7]);

        s1[4] = $signed(product_reg[8]);
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < 5; i++)
            s1_reg[i] <= s1[i];
    end

    // Stage 2: 5 -> 3

    logic signed [17:0] s2     [0:2];
    logic signed [17:0] s2_reg [0:2];

    always_comb begin
        s2[0] = $signed(s1_reg[0]) +
                $signed(s1_reg[1]);

        s2[1] = $signed(s1_reg[2]) +
                $signed(s1_reg[3]);

        s2[2] = $signed(s1_reg[4]);
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < 3; i++)
            s2_reg[i] <= s2[i];
    end

    // Stage 3: 3 -> 2
   

    logic signed [18:0] s3     [0:1];
    logic signed [18:0] s3_reg [0:1];

    always_comb begin
        s3[0] = $signed(s2_reg[0]) +
                $signed(s2_reg[1]);

        s3[1] = $signed(s2_reg[2]);
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < 2; i++)
            s3_reg[i] <= s3[i];
    end

    // Stage 4: 2 -> 1
    logic signed [19:0] conv_out;

    always_ff @(posedge clk) begin
        conv_out <= $signed(s3_reg[0]) +
                    $signed(s3_reg[1]);
    end

    // Valid / Done pipeline

    logic [3:0] valid_pipe;
    logic conv_out_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_pipe <= '0;
            conv_out_valid <= 1'b0;
        end
        else begin
            valid_pipe[0] <= input_valid;
            valid_pipe[1] <= valid_pipe[0];
            valid_pipe[2] <= valid_pipe[1];
            valid_pipe[3] <= valid_pipe[2];

            conv_out_valid <= valid_pipe[3];
        end
    end

    quantizer #(
        .IN_W(20),
        .OUT_W(8),
        .SHIFT(4)
    ) q1(
        .clk(clk),
        .rst(rst),
        .in_valid(conv_out_valid),
        .data_in(conv_out),

        .data_out(result_out),
        .out_valid(output_valid)
    );

endmodule