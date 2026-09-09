`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// Self-checking testbench for conv_pe_3x3_pipelined
//
// Strategy:
//   - A reference model (ref_conv) computes the expected 20-bit signed
//     convolution result in software, using the exact same fixed-point
//     rules as the DUT (window treated as unsigned 0-255, weights signed
//     8-bit, accumulated in a wide signed accumulator).
//   - Every time input_valid is driven high, the expected value is pushed
//     into a queue.
//   - Every time output_valid comes back high, the oldest expected value is
//     popped and compared against conv_out.
//   - Because the DUT never reorders transactions, queue (FIFO) ordering is
//     preserved even when bubbles (idle cycles) are inserted between valid
//     inputs, so this scoreboard works regardless of the exact pipeline
//     latency.
//
// Requires a SystemVerilog-capable simulator (Questa/ModelSim, VCS, Xcelium,
// Vivado xsim). Icarus Verilog has only partial SystemVerilog support and
// may not handle the queue / $urandom_range / automatic task constructs used
// here.
// ---------------------------------------------------------------------------

module tb_conv_pe_3x3_pipelined;

    // Clock / reset
    logic clk;
    logic rst;

    // DUT I/O
    logic                    input_valid;
    logic [7:0]              window  [0:8];
    logic signed [7:0]       weights [0:8];
    logic signed [19:0]      conv_out;
    logic                    output_valid;

    // Pipeline latency (cycles from input_valid=1 to the matching
    // output_valid=1) — used only to size the final drain wait, the
    // scoreboard itself does not depend on this being exact.
    localparam int PIPE_LATENCY = 5;

    // Scoreboard state
    logic signed [19:0] expected_q [$];
    int pass_count    = 0;
    int fail_count    = 0;
    int applied_count = 0;

    // ------------------------------------------------------------------
    // DUT instantiation
    // ------------------------------------------------------------------
    conv_pe_3x3_pipelined dut (
        .clk          (clk),
        .rst          (rst),
        .input_valid  (input_valid),
        .window       (window),
        .weights      (weights),
        .conv_out     (conv_out),
        .output_valid (output_valid)
    );

      
  	initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_conv_pe_3x3_pipelined);
	end

    // Clock generation: 10 ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Reference model — mirrors the DUT's math exactly
    // ------------------------------------------------------------------
    function automatic logic signed [19:0] ref_conv(
        input logic [7:0]        w [0:8],
        input logic signed [7:0] k [0:8]
    );
        logic signed [19:0] acc;
        begin
            acc = 20'sd0;
            for (int i = 0; i < 9; i++) begin
                acc = acc + ($signed({1'b0, w[i]}) * k[i]);
            end
            ref_conv = acc;
        end
    endfunction

    // ------------------------------------------------------------------
    // Drive one window/kernel pair for exactly one cycle with
    // input_valid = 1, and push the expected result into the scoreboard.
    // ------------------------------------------------------------------
    task automatic apply_case(
        input logic [7:0]        w [0:8],
        input logic signed [7:0] k [0:8]
    );
        begin
            @(negedge clk);
            for (int i = 0; i < 9; i++) begin
                window[i]  = w[i];
                weights[i] = k[i];
            end
            input_valid = 1'b1;
            expected_q.push_back(ref_conv(w, k));
            applied_count++;
            @(negedge clk);
            input_valid = 1'b0;
        end
    endtask

    // Insert N idle (bubble) cycles with input_valid low
    task automatic idle_cycles(input int n);
        begin
            repeat (n) begin
                @(negedge clk);
                input_valid = 1'b0;
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Scoreboard: check DUT output whenever output_valid is high
    // ------------------------------------------------------------------
    logic signed [19:0] exp_val;

    always @(posedge clk) begin
        if (!rst && output_valid) begin
            if (expected_q.size() == 0) begin
                $display("[%0t] ERROR: output_valid asserted but no expected value queued!", $time);
                fail_count++;
            end else begin
                exp_val = expected_q.pop_front();
                if (conv_out === exp_val) begin
                    $display("[%0t] PASS: conv_out = %0d (expected %0d)", $time, conv_out, exp_val);
                    pass_count++;
                end else begin
                    $display("[%0t] FAIL: conv_out = %0d, expected %0d", $time, conv_out, exp_val);
                    fail_count++;
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Directed + randomized stimulus
    // ------------------------------------------------------------------
    initial begin
        logic [7:0]        w_case [0:8];
        logic signed [7:0] k_case [0:8];

        // Reset
        rst         = 1'b1;
        input_valid = 1'b0;
        for (int i = 0; i < 9; i++) begin
            window[i]  = 8'd0;
            weights[i] = 8'sd0;
        end
        repeat (3) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);

        $display("==================================================");
        $display(" Starting conv_pe_3x3_pipelined testbench");
        $display("==================================================");

        // --- Directed case 1: all zeros -> expected 0 ---
        for (int i = 0; i < 9; i++) begin
            w_case[i] = 8'd0;
            k_case[i] = 8'sd0;
        end
        apply_case(w_case, k_case);

        // --- Directed case 2: all ones, all weights = 1 -> expected 9 ---
        for (int i = 0; i < 9; i++) begin
            w_case[i] = 8'd1;
            k_case[i] = 8'sd1;
        end
        apply_case(w_case, k_case);

        // --- Directed case 3: max positive window x max positive weight ---
        // 9 * 255 * 127 = 291,465 (well within +-2^19 range)
        for (int i = 0; i < 9; i++) begin
            w_case[i] = 8'd255;
            k_case[i] = 8'sd127;
        end
        apply_case(w_case, k_case);

        // --- Directed case 4: max positive window x most negative weight ---
        // 9 * 255 * (-128) = -293,760
        for (int i = 0; i < 9; i++) begin
            w_case[i] = 8'd255;
            k_case[i] = -8'sd128;
        end
        apply_case(w_case, k_case);

        // --- Directed case 5: alternating-sign weights, same window value ---
        for (int i = 0; i < 9; i++) begin
            w_case[i] = 8'd200;
            k_case[i] = (i % 2 == 0) ? 8'sd100 : -8'sd100;
        end
        apply_case(w_case, k_case);

        // --- Directed case 6: identity-like kernel (only center tap = 1) ---
        // expected = window[4] = 50
        for (int i = 0; i < 9; i++) begin
            w_case[i] = 8'd50;
            k_case[i] = 8'sd0;
        end
        k_case[4] = 8'sd1;
        apply_case(w_case, k_case);

        // --- Back-to-back throughput test: random cases, no bubbles ---
        $display("--- Back-to-back throughput test (no bubbles) ---");
        for (int t = 0; t < 10; t++) begin
            for (int i = 0; i < 9; i++) begin
                w_case[i] = $urandom_range(0, 255);
                k_case[i] = $signed($urandom_range(0, 255)) - 128; // -128..127
            end
            apply_case(w_case, k_case);
        end

        // --- Randomized cases with random bubble gaps between them ---
        $display("--- Randomized test with bubbles ---");
        for (int t = 0; t < 20; t++) begin
            for (int i = 0; i < 9; i++) begin
                w_case[i] = $urandom_range(0, 255);
                k_case[i] = $signed($urandom_range(0, 255)) - 128;
            end
            apply_case(w_case, k_case);
            idle_cycles($urandom_range(0, 3));
        end

        // Drain: wait enough cycles for all in-flight results to appear
        repeat (PIPE_LATENCY + 5) @(negedge clk);

        // ------------------------------------------------------------------
        // Final report
        // ------------------------------------------------------------------
        $display("==================================================");
        $display(" Testbench complete");
        $display(" Applied : %0d", applied_count);
        $display(" Passed  : %0d", pass_count);
        $display(" Failed  : %0d", fail_count);
        if (expected_q.size() != 0)
            $display(" WARNING: %0d expected results never checked (missing output_valid pulses)", expected_q.size());
        $display("==================================================");

        if (fail_count == 0 && expected_q.size() == 0)
            $display(" RESULT: ALL TESTS PASSED");
        else
            $display(" RESULT: TESTS FAILED");

        $finish;
    end

endmodule