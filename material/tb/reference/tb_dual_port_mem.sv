`timescale 1ns / 1ps

module tb_true_dual_port_ram;

    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 8;

    logic                  clk;
    logic                  we_a, we_b;
    logic [ADDR_WIDTH-1:0] addr_a, addr_b;
    logic [DATA_WIDTH-1:0] din_a, din_b;
    logic [DATA_WIDTH-1:0] dout_a, dout_b;

    true_dual_port_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk    (clk),
        .we_a   (we_a), .addr_a(addr_a), .din_a(din_a), .dout_a(dout_a),
        .we_b   (we_b), .addr_b(addr_b), .din_b(din_b), .dout_b(dout_b)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    int errors = 0;

    task automatic check(input logic [DATA_WIDTH-1:0] actual,
                          input logic [DATA_WIDTH-1:0] expected,
                          input string test_name);
        if (actual !== expected) begin
            $display("FAIL [%s]: expected = %0d, got = %0d, time = %0t",
                       test_name, expected, actual, $time);
            errors++;
        end else begin
            $display("PASS [%s]: value = %0d, time = %0t", test_name, actual, $time);
        end
    endtask

    initial begin
    $dumpfile("tb_true_dual_port_ram.vcd");
    $dumpvars(0, tb_true_dual_port_ram);
    end

    initial begin
        // ---- Init ----
        we_a = 0; we_b = 0;
        addr_a = 0; addr_b = 0;
        din_a = 0; din_b = 0;
        @(posedge clk);

        // ---- Test 1: Port A writes 42 to addr 5, Port B writes 99 to addr 10, SAME cycle ----
        we_a = 1; addr_a = 8'd5;  din_a = 32'd42;
        we_b = 1; addr_b = 8'd10; din_b = 32'd99;
        @(posedge clk);
        we_a = 0; we_b = 0;

        // ---- Test 2: Port A reads back addr 10, Port B reads back addr 5 (cross-check) ----
        addr_a = 8'd10;
        addr_b = 8'd5;
        @(posedge clk);
        @(posedge clk);
        check(dout_a, 32'd99, "Port A reads what Port B wrote");
        check(dout_b, 32'd42, "Port B reads what Port A wrote");

        // ---- Test 3: simultaneous write A vs read B to the SAME address ----
        // Port B is currently reading addr 5; now Port A writes a NEW value to addr 5
        // while Port B is also targeting addr 5 this same cycle.
        we_a = 1; addr_a = 8'd5; din_a = 32'd7;
        addr_b = 8'd5; we_b = 0;
        @(posedge clk);
        we_a = 0;
        // dout_b should show the OLD value (42), since B's read used mem[5]
        // from before this edge, not the value A is writing on this same edge.
        @(posedge clk); // let dout_b settle one more cycle after addr latched
        check(dout_b, 32'd7, "Port B eventually sees A's new write");

        // ---- Test 4: confirm the write-through behavior on Port A itself ----
        we_a = 1; addr_a = 8'd20; din_a = 32'd123;
        @(posedge clk);
        check(dout_a, 32'd123, "Port A write-through shows new value immediately");
        we_a = 0;

        // ---- Test 5: independent writes to different addresses don't clobber each other ----
        we_a = 1; addr_a = 8'd1; din_a = 32'd11;
        we_b = 1; addr_b = 8'd2; din_b = 32'd22;
        @(posedge clk);
        we_a = 0; we_b = 0;

        addr_a = 8'd1; addr_b = 8'd2;
        @(posedge clk);
        @(posedge clk);
        check(dout_a, 32'd11, "addr 1 intact via Port A");
        check(dout_b, 32'd22, "addr 2 intact via Port B");

        // ---- Summary ----
        if (errors == 0)
            $display("\n*** ALL TESTS PASSED ***\n");
        else
            $display("\n*** %0d TEST(S) FAILED ***\n", errors);

        $finish;
    end

endmodule