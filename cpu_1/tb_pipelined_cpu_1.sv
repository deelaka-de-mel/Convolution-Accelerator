module tb_pipelined_cpu_1();

    logic        clk;
    logic        reset;
    logic [7:0]  imem_addr;
    logic [7:0]  dmem_addr;
    logic [15:0] imem_rdata;
    logic [15:0] dmem_rdata;
    logic [15:0] dmem_wdata;
    logic        dmem_wen;

    // Instruction memory and Data memory arrays
    logic [15:0] imem [256];
    logic [15:0] dmem [256];

    // Instantiate the CPU
    pipelined_cpu uut (
        .clk(clk),
        .reset(reset),
        .imem_addr(imem_addr),
        .dmem_addr(dmem_addr),
        .imem_rdata(imem_rdata),
        .dmem_rdata(dmem_rdata),
        .dmem_wdata(dmem_wdata),
        .dmem_wen(dmem_wen)
    );

    // Clock generation (10 time units period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Memory read/write behavior
    assign imem_rdata = imem[imem_addr];
    assign dmem_rdata = dmem[dmem_addr];

    always_ff @(posedge clk) begin
        if (dmem_wen) begin
            dmem[dmem_addr] <= dmem_wdata;
            $display("Time %0t: DMEM WRITE addr=0x%0h, data=0x%0h", $time, dmem_addr, dmem_wdata);
        end
    end

    initial begin
        // Initialize memories
        for (int i = 0; i < 256; i++) begin
            imem[i] = '0;
            dmem[i] = '0;
        end

        // Preload Data Memory for testing LOAD/STORE
        dmem[8'h10] = 16'h002A; // Value 42 at address 0x10
        dmem[8'h11] = 16'h0005; // Value 5 at address 0x11

        // Instruction Encoding Reminders based on CPU decoding:
        // Opcode enum values: LOAD=0, STORE=1, MOVE=2, ADD=3, SUB=4, MUL=5, JNZ=6
        // R-type format: {i_rs2[3:0], i_rs1[3:0], i_rd[3:0], opcode[3:0]}
        // Mem/Branch format: {addr[7:0], i_reg[3:0], opcode[3:0]}

        // Example Program:
        // 0: LOAD R1 from addr 0x10  -> {8'h10, 4'h1, 4'h0} = 16'h1010
        imex_write(0, 16'h1010);

        // 1: LOAD R2 from addr 0x11  -> {8'h11, 4'h2, 4'h0} = 16'h1120
        imex_write(1, 16'h1120);

        // 2: ADD R3 = R1 + R2        -> {i_rs2=2, i_rs1=1, i_rd=3, ADD=3} = 16'h2133
        imex_write(2, 16'h2133);

        // 3: STORE R3 to addr 0x12   -> {8'h12, 4'h3, STORE=1} = 16'h1231
        imex_write(3, 16'h1231);

        // Reset sequence
        reset = 1;
        #12;
        reset = 0;

        // Run simulation long enough for pipeline to flush
        #100;
        
        // Print final register states
        $display("\n--- Final Register States ---");
        for (int i = 0; i < 4; i++) begin
            $display("R%0d = 0x%0h", i, uut.regs[i]);
        end
        $display("Data Memory [0x12] = 0x%0h (Expected: 0x2F / 47)", dmem[8'h12]);

        $finish;
    end

    // Task to load instructions easily
    task imex_write(input int addr, input logic [15:0] data);
        imem[addr] = data;
    endtask

    // Monitor pipeline progression
    initial begin
        $monitor("Time=%0t | PC=0x%0h | IF_IR=0x%0h | EX_Op=%0d | MemWEn=%b", 
                 $time, uut.pc, uut.if_id_ir, uut.id_ex_opcode, dmem_wen);
    end

endmodule