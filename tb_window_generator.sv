`timescale 1ns/1ps
module tb;
    parameter W = 256;
    parameter H = 256;
    parameter RANDOM_READY = 1;
    parameter RUNS = 2;

    logic clk = 0, reset = 1, start = 0;
    always #10 clk = ~clk;

    // CPU side of image_ram (PicoRV32 style)
    logic        sel = 0;
    logic [31:0] mem_addr = 0, mem_wdata = 0, mem_rdata;
    logic [3:0]  mem_wstrb = 0;
    logic        mem_ready;

    logic [15:0] image_addr;
    logic [7:0]  image_data;
    logic [71:0] tdata;
    logic tvalid, tready, tlast, done;

    image_ram ram (
        .clk(clk),
        .sel(sel), .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata), .mem_ready(mem_ready),
        .read_addr(image_addr), .read_data(image_data));

    // Unchanged window generator, only parameters set
    window_generator #(.IMAGE_WIDTH(W), .IMAGE_HEIGHT(H), .DATA_WIDTH(8), .ADDR_WIDTH(16)) dut (
        .clk(clk), .reset(reset), .start(start),
        .image_addr(image_addr), .image_data(image_data),
        .m_axis_tdata(tdata), .m_axis_tvalid(tvalid), .m_axis_tready(tready),
        .m_axis_tlast(tlast), .done(done));

    logic [7:0] img [0:W*H-1];
    integer r, c, n, errors, cycles, run, i;
    logic [71:0] expected, prev_data; logic prev_stall;

    always @(posedge clk) tready <= RANDOM_READY ? ($random % 3 != 0) : 1'b1;

    always @(posedge clk) begin
        if (!reset && prev_stall && (tdata !== prev_data || !tvalid)) begin
            $display("AXI VIOLATION at %0t", $time); errors = errors + 1;
        end
        prev_stall <= tvalid && !tready;
        prev_data  <= tdata;
    end

    // One CPU store, like PicoRV32: hold sel until mem_ready
    task automatic cpu_store(input [31:0] addr, input [31:0] data, input [3:0] strb);
        @(negedge clk);
        sel = 1; mem_addr = addr; mem_wdata = data; mem_wstrb = strb;
        @(posedge clk); while (!mem_ready) @(posedge clk);
        @(negedge clk); sel = 0; mem_wstrb = 0;
    endtask

    initial begin
        errors = 0; prev_stall = 0;
        for (run = 0; run < RUNS; run = run + 1) begin
            for (i = 0; i < W*H; i = i + 1) img[i] = $random;

            // First half with sw (4 pixels), second half with sb (1 pixel)
            for (i = 0; i < W*H; i = i + 4) begin
                if (i < W*H/2)
                    cpu_store(i, {img[i+3], img[i+2], img[i+1], img[i]}, 4'b1111);
                else
                    for (int b = 0; b < 4; b++)
                        cpu_store(i + b, {4{img[i+b]}}, 4'b0001 << b);
            end

            reset = 0;
            @(negedge clk); start = 1; @(negedge clk); start = 0;
            r = 2; c = 2; n = 0; cycles = 0;
            while (!done && cycles < W*H*20) begin
                @(posedge clk); cycles = cycles + 1;
                if (tvalid && tready) begin
                    expected = {img[(r-2)*W+c-2], img[(r-2)*W+c-1], img[(r-2)*W+c],
                                img[(r-1)*W+c-2], img[(r-1)*W+c-1], img[(r-1)*W+c],
                                img[(r  )*W+c-2], img[(r  )*W+c-1], img[(r  )*W+c]};
                    if (tdata !== expected) begin
                        if (errors < 5) $display("MISMATCH window %0d (r=%0d,c=%0d): got %h exp %h", n, r, c, tdata, expected);
                        errors = errors + 1;
                    end
                    if (tlast !== ((r == H-1) && (c == W-1))) begin
                        if (errors < 5) $display("TLAST wrong at window %0d", n);
                        errors = errors + 1;
                    end
                    n = n + 1;
                    if (c == W-1) begin c = 2; r = r + 1; end else c = c + 1;
                end
            end
            $display("run %0d: windows=%0d (expected %0d), cycles=%0d, done=%0d", run, n, (W-2)*(H-2), cycles, done);
            if (n != (W-2)*(H-2) || !done) errors = errors + 1;
            repeat (5) @(negedge clk);
        end
        if (errors == 0) $display("PASS"); else $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule