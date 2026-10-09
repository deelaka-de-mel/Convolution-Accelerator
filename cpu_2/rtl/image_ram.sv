module image_ram (
    input  logic        clk,
    input  logic        sel,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [3:0]  mem_wstrb,
    output logic [31:0] mem_rdata,
    output logic        mem_ready
);

    // 64x64 pixels = 4096 bytes = 1024 words (32-bit each)
    (* ramstyle = "M9K" *) reg [31:0] img_mem [0:1023];

    initial begin
        $readmemh("image.hex", img_mem);
    end

    wire [9:0] word_addr = mem_addr[11:2];

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

endmodule