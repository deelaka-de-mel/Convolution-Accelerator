
`timescale 1ns/1ps

module tb_conv_pe_3x3_pipelined_quantized;

    logic clk;
    logic rst;
    logic input_valid;

    logic [7:0] window [0:8];
    logic signed [7:0] weights [0:8];

    logic [7:0] result_out;
    logic output_valid;


    // --------------------------------------------------
    // DUT
    // --------------------------------------------------

    conv_pe_3x3_pipelined_quantized dut (
        .clk(clk),
        .rst(rst),
        .input_valid(input_valid),

        .window(window),
        .weights(weights),

        .result_out(result_out),
        .output_valid(output_valid)
    );


    // --------------------------------------------------
    // Clock
    // 10 ns period
    // --------------------------------------------------

    always #5 clk = ~clk;


    // --------------------------------------------------
    // Send one input window
    // --------------------------------------------------

    task send_input(input [7:0] value);
    begin
        @(negedge clk);            // drive away from the posedge
        for (int i = 0; i < 9; i++) window[i] = value;
        input_valid = 1'b1;
        @(negedge clk);
        input_valid = 1'b0;
    end
endtask


    // --------------------------------------------------
    // Test
    // --------------------------------------------------

    initial begin

        // VCD waveform dump
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb);


        // Initial values
        clk = 0;
        rst = 1;
        input_valid = 0;

        for (int i = 0; i < 9; i++) begin
            window[i] = 0;
            weights[i] = 1;
        end


        // Reset
        #20;
        rst = 0;


        // ------------------------------------------------
        // Five test inputs
        // ------------------------------------------------

        send_input(8'd10);
        send_input(8'd20);
        send_input(8'd30);
        send_input(8'd40);
        send_input(8'd50);


        // Wait for all pipeline results
        repeat (15)
            @(posedge clk);


        $finish;

    end


    // --------------------------------------------------
    // Display valid outputs
    // --------------------------------------------------

    always @(posedge clk) begin

        if (output_valid) begin

            $display(
                "TIME = %0t ns | RESULT = %0d",
                $time,
                result_out
            );

        end

    end

endmodule