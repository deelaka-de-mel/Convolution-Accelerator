// simple_ram.sv
//
// Minimal synchronous RAM for use as PicoRV32 program or data memory.
// - Word-addressed internally (byte address in, word index = addr[WORD_AWIDTH+1:2])
// - Byte-enable writes via mem_wstrb
// - One-cycle read/write latency, mem_ready pulses exactly one cycle after mem_valid
// - Intended to be instantiated twice from soc_top: once for program memory,
//   once for data memory. Replace with your teammate's memory module later --
//   the port list below is the contract soc_top expects.

module simple_ram #(
    parameter integer WORDS = 16384   // 16384 words * 4 bytes = 64KB
) (
    input  logic         clk,

    input  logic         mem_valid,
    output logic         mem_ready,
    input  logic [31:0]  mem_addr,    // byte address, only used for indexing (already decoded by caller)
    input  logic [31:0]  mem_wdata,
    input  logic [3:0]   mem_wstrb,
    output logic [31:0]  mem_rdata
);

    localparam integer AWIDTH = $clog2(WORDS);

    logic [31:0] mem [0:WORDS-1];

    wire [AWIDTH-1:0] word_addr = mem_addr[AWIDTH+1:2];

    // mem_ready pulses one cycle after a request is seen, and is deasserted otherwise.
    // This gives every access a fixed 1-cycle latency, matching PicoRV32's expectations
    // (mem_valid stays high until mem_ready fires).
    always_ff @(posedge clk) begin
        mem_ready <= mem_valid && !mem_ready;
    end

    always_ff @(posedge clk) begin
        if (mem_valid && !mem_ready) begin
            if (|mem_wstrb) begin
                if (mem_wstrb[0]) mem[word_addr][7:0]   <= mem_wdata[7:0];
                if (mem_wstrb[1]) mem[word_addr][15:8]  <= mem_wdata[15:8];
                if (mem_wstrb[2]) mem[word_addr][23:16] <= mem_wdata[23:16];
                if (mem_wstrb[3]) mem[word_addr][31:24] <= mem_wdata[31:24];
            end
            mem_rdata <= mem[word_addr];
        end
    end

endmodule
