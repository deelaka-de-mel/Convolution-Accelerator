module image_ram #(
    parameter ADDR_WIDTH = 18 // 256 KB = 65,536 words x 32 bits
)(
    input  logic        clk,
    
    // Port A: 32-bit CPU Memory Bus Interface
    input  logic        sel,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [3:0]  mem_wstrb,
    output logic [31:0] mem_rdata,
    output logic        mem_ready,

    // Port B: 8-bit Read Interface for window_generator
    input  logic [ADDR_WIDTH-1:0] read_addr,
    output logic [7:0]            read_data
);

    // Tell Quartus to initialize the M9K memory using image.mif
    (* ramstyle = "M9K, no_rw_check", ram_init_file = "image.mif" *)
    logic [31:0] memory [0:65535];

    wire [15:0] cpu_word_addr = mem_addr[17:2];
    wire [15:0] wg_word_addr  = read_addr[17:2];

    // Port A: CPU Read & Write Logic
    reg [31:0] cpu_rdata_reg;
    reg        ready_reg = 1'b0;

    always_ff @(posedge clk) begin
        ready_reg <= 1'b0;

        if (sel && !ready_reg) begin
            ready_reg <= 1'b1;

            if (mem_wstrb[0]) memory[cpu_word_addr][ 7: 0] <= mem_wdata[ 7: 0];
            if (mem_wstrb[1]) memory[cpu_word_addr][15: 8] <= mem_wdata[15: 8];
            if (mem_wstrb[2]) memory[cpu_word_addr][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) memory[cpu_word_addr][31:24] <= mem_wdata[31:24];

            cpu_rdata_reg <= memory[cpu_word_addr];
        end
    end

    assign mem_rdata = cpu_rdata_reg;
    assign mem_ready = ready_reg;

    // Port B: Window Generator Read Logic
    reg [31:0] port_b_word;

    always_ff @(posedge clk) begin
        port_b_word <= memory[wg_word_addr];
    end

    always_comb begin
        case (read_addr[1:0])
            2'b00:  read_data = port_b_word[ 7: 0];
            2'b01:  read_data = port_b_word[15: 8];
            2'b10:  read_data = port_b_word[23:16];
            2'b11:  read_data = port_b_word[31:24];
            default: read_data = 8'h00;
        endcase
    end

endmodule