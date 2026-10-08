module image_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 18
)(
    input  logic                  clk,
    input  logic                  cpu_we,
    input  logic [ADDR_WIDTH-1:0] cpu_addr,
    input  logic [DATA_WIDTH-1:0] cpu_wdata,
    input  logic [ADDR_WIDTH-1:0] read_addr,
    output logic [DATA_WIDTH-1:0] read_data
);
    (* ramstyle = "M9K, no_rw_check" *)
    logic [DATA_WIDTH-1:0] memory [0:(1<<ADDR_WIDTH)-1];
    always_ff @(posedge clk) begin
        if (cpu_we)
            memory[cpu_addr] <= cpu_wdata;
        read_data <= memory[read_addr];
    end
endmodule