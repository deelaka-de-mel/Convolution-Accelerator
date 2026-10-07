module conv_accel_regs_fake (
    input  logic        clk,
    input  logic        rst_n,

    // CPU Bus Interface
    input  logic        sel,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [3:0]  mem_wstrb,
    output logic [31:0] mem_rdata,
    output logic        mem_ready
);

    // Register Storage (Offsets 0x00 - 0x38)
    logic [31:0] reg_ctrl;        // 0x00: [0] START, [1] SOFT_RESET
    logic [31:0] reg_status;      // 0x04: [0] BUSY, [1] DONE, [2] ERROR
    logic [31:0] reg_img_addr;    // 0x08: Image Word Address
    logic [31:0] reg_size;        // 0x0C: [15:0] WIDTH, [31:16] HEIGHT
    logic [31:0] k_regs [0:8];    // 0x10 - 0x30: K0 to K8
    logic [31:0] reg_shift;       // 0x34: [4:0] Shift
    logic [31:0] reg_cycles;      // 0x38: Busy Cycle Counter

    // Fake Hardware Execution State Machine
    logic [3:0]  delay_counter;
    logic        running;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running       <= 1'b0;
            delay_counter <= 4'd0;
            reg_cycles    <= 32'd0;
            reg_status    <= 32'd0;
        end else begin
            if (reg_ctrl[0]) begin // START pulse received
                running       <= 1'b1;
                delay_counter <= 4'd0;
                reg_cycles    <= 32'd0;
                reg_status    <= 32'h1; // Set BUSY = 1, DONE = 0
            end else if (running) begin
                reg_cycles <= reg_cycles + 1'b1;
                if (delay_counter == 4'd15) begin
                    running    <= 1'b0;
                    reg_status <= 32'h2; // Set BUSY = 0, DONE = 1 (sticky)
                end else begin
                    delay_counter <= delay_counter + 1'b1;
                end
            end
        end
    end

    // 1-Cycle Bus Latency Interface
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready    <= 1'b0;
            mem_rdata    <= 32'd0;
            reg_ctrl     <= 32'd0;
            reg_img_addr <= 32'd0;
            reg_size     <= {16'd512, 16'd512};
            reg_shift    <= 32'd0;
            for (int i = 0; i < 9; i++) k_regs[i] <= 32'd0;
        end else begin
            mem_ready <= 1'b0;
            reg_ctrl  <= 32'd0; // Self-clearing START pulse

            if (sel && !mem_ready) begin
                mem_ready <= 1'b1;

                if (|mem_wstrb) begin
                    case (mem_addr[7:0])
                        8'h00: reg_ctrl     <= mem_wdata;
                        8'h08: reg_img_addr <= mem_wdata;
                        8'h0C: reg_size     <= mem_wdata;
                        8'h10: k_regs[0]    <= mem_wdata;
                        8'h14: k_regs[1]    <= mem_wdata;
                        8'h18: k_regs[2]    <= mem_wdata;
                        8'h1C: k_regs[3]    <= mem_wdata;
                        8'h20: k_regs[4]    <= mem_wdata;
                        8'h24: k_regs[5]    <= mem_wdata;
                        8'h28: k_regs[6]    <= mem_wdata;
                        8'h2C: k_regs[7]    <= mem_wdata;
                        8'h30: k_regs[8]    <= mem_wdata;
                        8'h34: reg_shift    <= mem_wdata;
                    endcase
                end else begin
                    case (mem_addr[7:0])
                        8'h00: mem_rdata <= reg_ctrl;
                        8'h04: mem_rdata <= reg_status;
                        8'h08: mem_rdata <= reg_img_addr;
                        8'h0C: mem_rdata <= reg_size;
                        8'h10: mem_rdata <= k_regs[0];
                        8'h14: mem_rdata <= k_regs[1];
                        8'h18: mem_rdata <= k_regs[2];
                        8'h1C: mem_rdata <= k_regs[3];
                        8'h20: mem_rdata <= k_regs[4];
                        8'h24: mem_rdata <= k_regs[5];
                        8'h28: mem_rdata <= k_regs[6];
                        8'h2C: mem_rdata <= k_regs[7];
                        8'h30: mem_rdata <= k_regs[8];
                        8'h34: mem_rdata <= reg_shift;
                        8'h38: mem_rdata <= reg_cycles;
                        default: mem_rdata <= 32'd0;
                    endcase
                end
            end
        end
    end
endmodule