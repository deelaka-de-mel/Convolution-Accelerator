module conv_pe_3x3_tb;

    logic [7:0]         window  [0:8];
    logic signed [7:0]  weights [0:8];
    logic signed [19:0] conv_out;

    conv_pe_3x3 dut (
        .window(window),
        .weights(weights),
        .conv_out(conv_out)
    );

    initial begin
        window  = '{10, 20, 30, 40, 50, 60, 70, 80, 90};
        weights = '{-1, 0, 1, -2, 0, 2, -1, 0, 1};
        #10;
        $display("conv_out = %0d (expect 80)", conv_out);
        $finish;
    end

endmodule