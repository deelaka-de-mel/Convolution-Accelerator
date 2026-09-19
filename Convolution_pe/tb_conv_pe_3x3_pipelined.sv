`timescale 1ns/1ps

module tb_conv_pe_3x3_pipelined;

    logic clk;
    logic rst;
    logic input_valid;

    logic [7:0] window [0:8];
    logic signed [7:0] weights [0:8];

    logic signed [19:0] conv_out;
    logic output_valid;

    logic signed [19:0] expected [0:9];

    integer test_count = 0;

    conv_pe_3x3_pipelined dut (
        .clk(clk),
        .rst(rst),
        .input_valid(input_valid),
        .window(window),
        .weights(weights),
        .conv_out(conv_out),
        .output_valid(output_valid)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;


    // =====================================================
    // CHECK OUTPUTS
    // =====================================================

    always @(posedge clk) begin

        if (output_valid) begin

            if (conv_out == expected[test_count]) begin
                $display("TEST %0d PASSED: Expected = %0d, Got = %0d",
                         test_count + 1,
                         expected[test_count],
                         conv_out);
            end
            else begin
                $display("TEST %0d FAILED: Expected = %0d, Got = %0d",
                         test_count + 1,
                         expected[test_count],
                         conv_out);
            end

            test_count = test_count + 1;

        end

    end


    // =====================================================
    // TESTS
    // =====================================================

    initial begin

        rst = 1;
        input_valid = 0;

        for (int i = 0; i < 9; i++) begin
            window[i] = 0;
            weights[i] = 0;
        end

        // Expected results
        expected[0] = 9;
        expected[1] = 54;
        expected[2] = 450;
        expected[3] = 291465;
        expected[4] = -293760;
        expected[5] = 200;
        expected[6] = 50;
        expected[7] = 360;
        expected[8] = -360;
        expected[9] = 285;

        // Reset
        repeat (2) @(posedge clk);
        rst = 0;


        // -------------------------------------------------
        // TEST 1
        // -------------------------------------------------

        @(negedge clk);

        for (int i = 0; i < 9; i++) begin
            window[i] = 1;
            weights[i] = 1;
        end

        input_valid = 1;


        // -------------------------------------------------
        // TEST 2
        // -------------------------------------------------

        @(negedge clk);

        for (int i = 0; i < 9; i++) begin
            window[i] = 2;
            weights[i] = 3;
        end


        // -------------------------------------------------
        // TEST 3
        // -------------------------------------------------

        @(negedge clk);

        for (int i = 0; i < 9; i++) begin
            window[i] = 10;
            weights[i] = 5;
        end


        // -------------------------------------------------
        // TEST 4
        // -------------------------------------------------

        @(negedge clk);

        for (int i = 0; i < 9; i++) begin
            window[i] = 255;
            weights[i] = 127;
        end


        // -------------------------------------------------
        // TEST 5
        // -------------------------------------------------

        @(negedge clk);

        for (int i = 0; i < 9; i++) begin
            window[i] = 255;
            weights[i] = -128;
        end


        // -------------------------------------------------
        // TEST 6
        // -------------------------------------------------

        @(negedge clk);

        for (int i = 0; i < 9; i++) begin
            window[i] = 20;
            weights[i] = (i % 2 == 0) ? 10 : -10;
        end


        // -------------------------------------------------
        // TEST 7
        // -------------------------------------------------

        @(negedge clk);

        for (int i = 0; i < 9; i++) begin
            window[i] = 50;
            weights[i] = 0;
        end

        weights[4] = 1;


        // -------------------------------------------------
        // TEST 8
        // -------------------------------------------------

        @(negedge clk);

        for (int i = 0; i < 9; i++) begin
            window[i] = i * 10;
            weights[i] = 1;
        end


        // -------------------------------------------------
        // TEST 9
        // -------------------------------------------------

        @(negedge clk);

        for (int i = 0; i < 9; i++) begin
            window[i] = i * 10;
            weights[i] = -1;
        end


        // -------------------------------------------------
        // TEST 10
        // -------------------------------------------------

        @(negedge clk);

        window[0] = 1;  weights[0] = 1;
        window[1] = 2;  weights[1] = 2;
        window[2] = 3;  weights[2] = 3;
        window[3] = 4;  weights[3] = 4;
        window[4] = 5;  weights[4] = 5;
        window[5] = 6;  weights[5] = 6;
        window[6] = 7;  weights[6] = 7;
        window[7] = 8;  weights[7] = 8;
        window[8] = 9;  weights[8] = 9;


        // Stop input
        @(negedge clk);
        input_valid = 0;


        // Wait for pipeline to empty
        repeat (10) @(posedge clk);

        $finish;

    end

endmodule