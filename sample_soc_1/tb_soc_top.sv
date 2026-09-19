`timescale 1ns/1ps

// tb_soc_top.sv
//
// Drives soc_top with a hand-assembled RV32I test program (no toolchain
// needed). The program:
//   1. Loads ACCEL_BASE (0x0002_0000) into x28
//   2. Writes 9 pixels (10,20,...,90) to PIXEL[0..8]
//   3. Writes 9 weights (-1,0,1,-2,0,2,-1,0,1) to WEIGHT[0..8]
//   4. Writes CTRL=1 to pulse START
//   5. Polls STATUS until it reads nonzero (busy-wait loop)
//   6. Reads RESULT into x29
//   7. Halts in a self-loop (jal x0, 0)
//
// Expected result once the real conv_pe_3x3_pipelined is wired in:
// conv_out = 80 for this pixel/weight pair (matches the worked example
// used earlier). With the PLACEHOLDER COMPUTE currently in
// conv_accel_regs.sv (same formula, just combinational + fake latency),
// x29 should also land on 80 -- this testbench exercises the CPU/bus
// path end-to-end even before the pipelined PE is dropped in.
//
// This testbench forces the program directly into u_prog_ram's memory
// array via hierarchical reference, bypassing any $readmemh/toolchain
// dependency. Swap to $readmemh once a compiled .hex is available.

module tb_soc_top;

    logic clk;
    logic resetn;

    soc_top dut (
        .clk    (clk),
        .resetn (resetn)
    );

    // Clock: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------
    // Hand-assembled program (see assemble_test.py for derivation)
    // -----------------------------------------------------------
    initial begin
        dut.u_prog_ram.mem[0]  = 32'h00020e37; // lui   x28, ACCEL_BASE>>12
        dut.u_prog_ram.mem[1]  = 32'h00a00293; // addi  x5, x0, 10
        dut.u_prog_ram.mem[2]  = 32'h005e2023; // sw    x5, 0x00(x28)   PIXEL[0]
        dut.u_prog_ram.mem[3]  = 32'h01400293; // addi  x5, x0, 20
        dut.u_prog_ram.mem[4]  = 32'h005e2223; // sw    x5, 0x04(x28)   PIXEL[1]
        dut.u_prog_ram.mem[5]  = 32'h01e00293; // addi  x5, x0, 30
        dut.u_prog_ram.mem[6]  = 32'h005e2423; // sw    x5, 0x08(x28)   PIXEL[2]
        dut.u_prog_ram.mem[7]  = 32'h02800293; // addi  x5, x0, 40
        dut.u_prog_ram.mem[8]  = 32'h005e2623; // sw    x5, 0x0c(x28)   PIXEL[3]
        dut.u_prog_ram.mem[9]  = 32'h03200293; // addi  x5, x0, 50
        dut.u_prog_ram.mem[10] = 32'h005e2823; // sw    x5, 0x10(x28)   PIXEL[4]
        dut.u_prog_ram.mem[11] = 32'h03c00293; // addi  x5, x0, 60
        dut.u_prog_ram.mem[12] = 32'h005e2a23; // sw    x5, 0x14(x28)   PIXEL[5]
        dut.u_prog_ram.mem[13] = 32'h04600293; // addi  x5, x0, 70
        dut.u_prog_ram.mem[14] = 32'h005e2c23; // sw    x5, 0x18(x28)   PIXEL[6]
        dut.u_prog_ram.mem[15] = 32'h05000293; // addi  x5, x0, 80
        dut.u_prog_ram.mem[16] = 32'h005e2e23; // sw    x5, 0x1c(x28)   PIXEL[7]
        dut.u_prog_ram.mem[17] = 32'h05a00293; // addi  x5, x0, 90
        dut.u_prog_ram.mem[18] = 32'h025e2023; // sw    x5, 0x20(x28)   PIXEL[8]
        dut.u_prog_ram.mem[19] = 32'hfff00293; // addi  x5, x0, -1
        dut.u_prog_ram.mem[20] = 32'h025e2223; // sw    x5, 0x24(x28)   WEIGHT[0]
        dut.u_prog_ram.mem[21] = 32'h00000293; // addi  x5, x0, 0
        dut.u_prog_ram.mem[22] = 32'h025e2423; // sw    x5, 0x28(x28)   WEIGHT[1]
        dut.u_prog_ram.mem[23] = 32'h00100293; // addi  x5, x0, 1
        dut.u_prog_ram.mem[24] = 32'h025e2623; // sw    x5, 0x2c(x28)   WEIGHT[2]
        dut.u_prog_ram.mem[25] = 32'hffe00293; // addi  x5, x0, -2
        dut.u_prog_ram.mem[26] = 32'h025e2823; // sw    x5, 0x30(x28)   WEIGHT[3]
        dut.u_prog_ram.mem[27] = 32'h00000293; // addi  x5, x0, 0
        dut.u_prog_ram.mem[28] = 32'h025e2a23; // sw    x5, 0x34(x28)   WEIGHT[4]
        dut.u_prog_ram.mem[29] = 32'h00200293; // addi  x5, x0, 2
        dut.u_prog_ram.mem[30] = 32'h025e2c23; // sw    x5, 0x38(x28)   WEIGHT[5]
        dut.u_prog_ram.mem[31] = 32'hfff00293; // addi  x5, x0, -1
        dut.u_prog_ram.mem[32] = 32'h025e2e23; // sw    x5, 0x3c(x28)   WEIGHT[6]
        dut.u_prog_ram.mem[33] = 32'h00000293; // addi  x5, x0, 0
        dut.u_prog_ram.mem[34] = 32'h045e2023; // sw    x5, 0x40(x28)   WEIGHT[7]
        dut.u_prog_ram.mem[35] = 32'h00100293; // addi  x5, x0, 1
        dut.u_prog_ram.mem[36] = 32'h045e2223; // sw    x5, 0x44(x28)   WEIGHT[8]
        dut.u_prog_ram.mem[37] = 32'h00100293; // addi  x5, x0, 1
        dut.u_prog_ram.mem[38] = 32'h045e2423; // sw    x5, 0x48(x28)   CTRL = 1 (start)
        dut.u_prog_ram.mem[39] = 32'h04ce2303; // L_POLL: lw x6, 0x4c(x28)  STATUS
        dut.u_prog_ram.mem[40] = 32'h00100393; // addi  x7, x0, 1
        dut.u_prog_ram.mem[41] = 32'hfe030ce3; // beq   x6, x0, L_POLL
        dut.u_prog_ram.mem[42] = 32'h050e2e83; // lw    x29, 0x50(x28)  RESULT
        dut.u_prog_ram.mem[43] = 32'h0000006f; // HALT: jal x0, 0 (self loop)
    end

    // -----------------------------------------------------------
    // Reset and run
    // -----------------------------------------------------------
    initial begin
        resetn = 0;
        repeat (5) @(posedge clk);
        resetn = 1;

        // Run long enough for ~44 instructions plus poll spin plus
        // pipeline latency. Generous margin for a first pass.
        repeat (500) @(posedge clk);

        $display("---------------------------------------------");
        $display("x29 (RESULT read into register) = %0d", $signed(dut.u_cpu.cpuregs[29]));
        $display("Expected (for this pixel/weight combination)  = 80");
        if ($signed(dut.u_cpu.cpuregs[29]) == 80)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
        $display("---------------------------------------------");

        $finish;
    end

    // Optional: watch STATUS/CTRL/RESULT registers directly for debug
    initial begin
        $dumpfile("tb_soc_top.vcd");
        $dumpvars(0, tb_soc_top);
    end

endmodule
