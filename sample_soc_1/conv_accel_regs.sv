// conv_accel_regs.sv
//
// Memory-mapped register file / bus wrapper for the 3x3 convolution
// accelerator. This is the CPU-facing contract: address offsets, register
// widths, CTRL/STATUS semantics. Everything below "PLACEHOLDER COMPUTE"
// is a stand-in until conv_pe_3x3_pipelined is wired in by the teammate
// building the accelerator -- at that point, delete the placeholder
// always_ff block and replace it with an instance of the real PE, driven
// by the same window[]/weights[]/input_valid signals and read back from
// the same conv_out/output_valid signals. No change needed on the CPU/
// bus side of this module.
//
// Address map (offsets from this module's base address, e.g. 0x0002_0000):
//   0x00 .. 0x20   PIXEL[0..8]    (9 x 4B, only [7:0] used, rest ignored on write/read as 0)
//   0x24 .. 0x44   WEIGHT[0..8]   (9 x 4B, only [7:0] used, sign bit at [7])
//   0x48           CTRL           bit0 = START (write 1 to pulse input_valid for 1 cycle)
//   0x4C           STATUS         bit0 = DONE (latched output_valid, cleared on START)
//   0x50           RESULT         sign-extended conv_out (20-bit -> 32-bit)
//
// All accesses are word-aligned 32-bit; sub-word accesses are not supported
// (mem_wstrb is honored for writes, but reads always return the full word).

module conv_accel_regs (
    input  logic         clk,
    input  logic         rst,       // active-high, synchronous

    input  logic         mem_valid,
    output logic         mem_ready,
    input  logic [31:0]  mem_addr,   // already offset-relative to this module's base (see soc_top decode)
    input  logic [31:0]  mem_wdata,
    input  logic [3:0]   mem_wstrb,
    output logic [31:0]  mem_rdata
);

    // ---------------------------------------------------------------
    // Register offsets (byte addresses relative to module base)
    // ---------------------------------------------------------------
    localparam int PIXEL_BASE  = 12'h000;  // 0x00
    localparam int WEIGHT_BASE = 12'h024;  // 0x24
    localparam int CTRL_ADDR   = 12'h048;
    localparam int STATUS_ADDR = 12'h04C;
    localparam int RESULT_ADDR = 12'h050;

    // ---------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------
    logic [7:0]         pixel_reg  [0:8];
    logic signed [7:0]  weight_reg [0:8];
    logic                start_pulse;
    logic                done_latched;
    logic signed [19:0]  result_reg;

    // ---------------------------------------------------------------
    // PE-facing signals (this is the contract the real PE plugs into)
    // ---------------------------------------------------------------
    logic [7:0]          window  [0:8];
    logic signed [7:0]   weights [0:8];
    logic                 input_valid;
    logic signed [19:0]  conv_out;
    logic                 output_valid;

    assign window      = pixel_reg;
    assign weights     = weight_reg;
    assign input_valid = start_pulse;

    // ---------------------------------------------------------------
    // Bus request decode (word index within this module)
    // ---------------------------------------------------------------
    wire [11:0] byte_off = mem_addr[11:0];

    // one-cycle-latency bus, same convention as simple_ram
    always_ff @(posedge clk) begin
        if (rst)
            mem_ready <= 1'b0;
        else
            mem_ready <= mem_valid && !mem_ready;
    end

    logic access_fire;
    assign access_fire = mem_valid && !mem_ready;

    // ---------------------------------------------------------------
    // Writes
    // ---------------------------------------------------------------
    integer i;
    always_ff @(posedge clk) begin
        start_pulse <= 1'b0; // default: only high for exactly 1 cycle

        if (rst) begin
            for (i = 0; i < 9; i = i + 1) begin
                pixel_reg[i]  <= 8'd0;
                weight_reg[i] <= 8'sd0;
            end
            done_latched <= 1'b0;
        end
        else if (access_fire && |mem_wstrb) begin
            if (byte_off >= PIXEL_BASE && byte_off < PIXEL_BASE + 9*4) begin
                pixel_reg[(byte_off - PIXEL_BASE) >> 2] <= mem_wdata[7:0];
            end
            else if (byte_off >= WEIGHT_BASE && byte_off < WEIGHT_BASE + 9*4) begin
                weight_reg[(byte_off - WEIGHT_BASE) >> 2] <= mem_wdata[7:0];
            end
            else if (byte_off == CTRL_ADDR) begin
                if (mem_wdata[0]) begin
                    start_pulse  <= 1'b1;
                    done_latched <= 1'b0; // clear DONE when a new computation starts
                end
            end
        end

        // Latch DONE when the PE reports output_valid, unless a fresh
        // START is issued in the same cycle (START wins).
        if (!rst && output_valid && !(access_fire && |mem_wstrb &&
                byte_off == CTRL_ADDR && mem_wdata[0])) begin
            done_latched <= 1'b1;
            result_reg   <= conv_out;
        end
    end

    // ---------------------------------------------------------------
    // Reads
    // ---------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (access_fire && !(|mem_wstrb)) begin
            if (byte_off >= PIXEL_BASE && byte_off < PIXEL_BASE + 9*4)
                mem_rdata <= {24'd0, pixel_reg[(byte_off - PIXEL_BASE) >> 2]};
            else if (byte_off >= WEIGHT_BASE && byte_off < WEIGHT_BASE + 9*4)
                mem_rdata <= {{24{weight_reg[(byte_off - WEIGHT_BASE) >> 2][7]}},
                              weight_reg[(byte_off - WEIGHT_BASE) >> 2]};
            else if (byte_off == CTRL_ADDR)
                mem_rdata <= 32'd0;
            else if (byte_off == STATUS_ADDR)
                mem_rdata <= {31'd0, done_latched};
            else if (byte_off == RESULT_ADDR)
                mem_rdata <= {{12{result_reg[19]}}, result_reg};
            else
                mem_rdata <= 32'd0;
        end
    end

    // =================================================================
    // PLACEHOLDER COMPUTE -- delete this block and instantiate the real
    // conv_pe_3x3_pipelined here once it's ready. Keep the port names
    // (window, weights, input_valid -> conv_out, output_valid) identical
    // so nothing above this line needs to change.
    // =================================================================
    logic [3:0] valid_delay;
    always_ff @(posedge clk) begin
        if (rst) begin
            valid_delay <= 4'd0;
        end else begin
            valid_delay <= {valid_delay[2:0], input_valid};
        end
    end
    assign output_valid = valid_delay[3]; // fake ~5-stage latency like the real PE

    always_comb begin
        // Trivial placeholder: sum of (pixel*weight) computed combinationally,
        // just so the register interface is exercisable before the real PE exists.
        conv_out = 20'sd0;
        for (int k = 0; k < 9; k = k + 1)
            conv_out = conv_out + ($signed({1'b0, window[k]}) * weights[k]);
    end
    // =================================================================
    // END PLACEHOLDER COMPUTE
    // =================================================================

endmodule
