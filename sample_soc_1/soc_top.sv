// soc_top.sv
//
// Minimal PicoRV32-based SoC shell.
//
// Address map:
//   0x0000_0000 - 0x0000_FFFF   Program memory (64KB)   -> simple_ram (prog)
//   0x0001_0000 - 0x0001_FFFF   Data memory    (64KB)   -> simple_ram (data)
//   0x0002_0000 - 0x0002_0FFF   Accelerator regs (4KB)  -> conv_accel_regs
//   anything else                                       -> unmapped, mem_ready never asserted (will hang -- add a bus error/watchdog when needed)
//
// Bus convention: single native picorv32 mem interface, valid/ready,
// one target selected per transaction based on mem_addr[31:16].

module soc_top (
    input  logic clk,
    input  logic resetn
);

    // -----------------------------------------------------------
    // PicoRV32 <-> bus signals
    // -----------------------------------------------------------
    logic        mem_valid;
    logic        mem_instr;
    logic        mem_ready;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wstrb;
    logic [31:0] mem_rdata;

    // -----------------------------------------------------------
    // Address decode
    // -----------------------------------------------------------
    localparam logic [15:0] SEL_PROG  = 16'h0000; // 0x0000_xxxx
    localparam logic [15:0] SEL_DATA  = 16'h0001; // 0x0001_xxxx
    localparam logic [15:0] SEL_ACCEL = 16'h0002; // 0x0002_xxxx

    wire [15:0] sel = mem_addr[31:16];

    wire prog_sel  = mem_valid && (sel == SEL_PROG);
    wire data_sel  = mem_valid && (sel == SEL_DATA);
    wire accel_sel = mem_valid && (sel == SEL_ACCEL);

    // -----------------------------------------------------------
    // Program memory
    // -----------------------------------------------------------
    logic        prog_ready;
    logic [31:0] prog_rdata;

    simple_ram #(.WORDS(16384)) u_prog_ram (
        .clk       (clk),
        .mem_valid (prog_sel),
        .mem_ready (prog_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (prog_sel ? mem_wstrb : 4'b0000),
        .mem_rdata (prog_rdata)
    );

    // -----------------------------------------------------------
    // Data memory
    // -----------------------------------------------------------
    logic        data_ready;
    logic [31:0] data_rdata;

    simple_ram #(.WORDS(16384)) u_data_ram (
        .clk       (clk),
        .mem_valid (data_sel),
        .mem_ready (data_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (data_sel ? mem_wstrb : 4'b0000),
        .mem_rdata (data_rdata)
    );

    // -----------------------------------------------------------
    // Accelerator registers
    // -----------------------------------------------------------
    logic        accel_ready;
    logic [31:0] accel_rdata;

    conv_accel_regs u_conv_accel (
        .clk       (clk),
        .rst       (~resetn),
        .mem_valid (accel_sel),
        .mem_ready (accel_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (accel_sel ? mem_wstrb : 4'b0000),
        .mem_rdata (accel_rdata)
    );

    // -----------------------------------------------------------
    // Response mux
    // -----------------------------------------------------------
    always_comb begin
        mem_ready = 1'b0;
        mem_rdata = 32'd0;
        if (prog_sel) begin
            mem_ready = prog_ready;
            mem_rdata = prog_rdata;
        end
        else if (data_sel) begin
            mem_ready = data_ready;
            mem_rdata = data_rdata;
        end
        else if (accel_sel) begin
            mem_ready = accel_ready;
            mem_rdata = accel_rdata;
        end
        // else: unmapped access, mem_ready stays 0 (core will stall --
        // fine for now, add a bus-error timeout later if needed)
    end

    // -----------------------------------------------------------
    // PicoRV32 core
    // -----------------------------------------------------------
    picorv32 #(
        .ENABLE_COUNTERS     (0),
        .ENABLE_COUNTERS64   (0),
        .ENABLE_REGS_16_31   (1),
        .ENABLE_REGS_DUALPORT(1),
        .BARREL_SHIFTER      (1),
        .COMPRESSED_ISA      (0),
        .CATCH_MISALIGN      (1),
        .CATCH_ILLINSN       (1),
        .ENABLE_PCPI         (0),
        .ENABLE_MUL          (0),
        .ENABLE_DIV          (0),
        .ENABLE_IRQ          (0),   // polling for now; flip on later for interrupt-driven done
        .PROGADDR_RESET      (32'h0000_0000),
        .PROGADDR_IRQ        (32'h0000_0010),
        .STACKADDR           (32'h0001_FFFC)
    ) u_cpu (
        .clk        (clk),
        .resetn     (resetn),
        .trap       (),

        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_ready  (mem_ready),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_rdata  (mem_rdata),

        .mem_la_read (),
        .mem_la_write(),
        .mem_la_addr (),
        .mem_la_wdata(),
        .mem_la_wstrb(),

        .pcpi_valid (),
        .pcpi_insn  (),
        .pcpi_rs1   (),
        .pcpi_rs2   (),
        .pcpi_wr    (1'b0),
        .pcpi_rd    (32'd0),
        .pcpi_wait  (1'b0),
        .pcpi_ready (1'b0),

        .irq        (32'd0),
        .eoi        (),

        .trace_valid(),
        .trace_data ()
    );

endmodule
