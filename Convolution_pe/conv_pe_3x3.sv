module conv_pe_3x3 (
    input  logic [7:0]         window  [0:8],   // 9 pixels
    input  logic signed [7:0]  weights [0:8],   // 9 kernel weights
    output logic signed [19:0] conv_out
);

    logic signed [15:0] product [0:8];

    // Stage 0: 9 parallel multiplies
    always_comb begin
        for (int i = 0; i < 9; i++) begin
            product[i] = $signed({1'b0, window[i]}) * weights[i];
        end
    end

    // Stage 1: 9 -> 5
    logic signed [16:0] s1_0, s1_1, s1_2, s1_3, s1_4;
    always_comb begin
        s1_0 = product[0] + product[1];
        s1_1 = product[2] + product[3];
        s1_2 = product[4] + product[5];
        s1_3 = product[6] + product[7];
        s1_4 = product[8];              // carried forward
    end

    // Stage 2: 5 -> 3
    logic signed [17:0] s2_0, s2_1, s2_2;
    always_comb begin
        s2_0 = s1_0 + s1_1;
        s2_1 = s1_2 + s1_3;
        s2_2 = s1_4;                    // carried forward
    end

    // Stage 3: 3 -> 2
    logic signed [18:0] s3_0, s3_1;
    always_comb begin
        s3_0 = s2_0 + s2_1;
        s3_1 = s2_2;                    // carried forward
    end

    // Stage 4: 2 -> 1 (final result)
    always_comb begin
        conv_out = s3_0 + s3_1;
    end

endmodule