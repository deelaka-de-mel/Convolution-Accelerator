module image_ram (
    input  logic        clk,

    // ============================================================
    // CPU port (PicoRV32 bus)
    // ============================================================

    input  logic        sel,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [3:0]  mem_wstrb,
    output logic [31:0] mem_rdata,
    output logic        mem_ready,

    // ============================================================
    // Window generator read port
    //
    // read_addr is a pixel (byte) address, presented in cycle N.
    // read_data is that pixel, returned in cycle N+1.
    // ============================================================

    input  logic [15:0] read_addr,
    output logic [7:0]  read_data
);

    // 256x256 pixels = 65536 bytes = 16384 words (32-bit each)
    (* ramstyle = "M9K" *) reg [31:0] img_mem [0:16383];

    initial begin
        $readmemh("image.hex", img_mem);
    end

    wire [13:0] word_addr = mem_addr[15:2];

    // CPU port
    always_ff @(posedge clk) begin
        mem_ready <= sel && !mem_ready;
        if (sel && !mem_ready) begin
            if (mem_wstrb[0]) img_mem[word_addr][ 7: 0] <= mem_wdata[ 7: 0];
            if (mem_wstrb[1]) img_mem[word_addr][15: 8] <= mem_wdata[15: 8];
            if (mem_wstrb[2]) img_mem[word_addr][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) img_mem[word_addr][31:24] <= mem_wdata[31:24];
            mem_rdata <= img_mem[word_addr];
        end
    end

    // Window generator port
    //
    // Read the word holding the pixel, then pick its byte using
    // the lowest 2 address bits (little-endian, same as the CPU)
    reg [31:0] read_word;
    reg [1:0]  read_lane;

    always_ff @(posedge clk) begin
        read_word <= img_mem[read_addr[15:2]];
        read_lane <= read_addr[1:0];
    end

    always_comb begin
        read_data = read_word[read_lane*8 +: 8];
    end

endmodule