module dual_port_mem(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
    )(
        input logic clk,
        
        //PORT A
        input logic we_a,
        input logic [ADDR_WIDTH - 1:0] addr_a,
        input logic [DATA_WIDTH - 1:0] data_ina,
        output logic [DATA_WIDTH - 1:0] data_outa,

        //PORT B
        input logic we_b,
        input logic [ADDR_WIDTH - 1:0] addr_a,
        input logic [DATA_WIDTH - 1:0] data_inb,
        output logic [DATA_WIDTH - 1:0] data_outb,
    );

    logic [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

    //PORT A
    always_ff (@ posedge clk) begin
        if(we_a) begin
            mem[addr_a] <= data_ina;
            else begin
                data_outa <= mem[addr_a];
            end
        end
    end

    //PORT B
    always_ff (@ posedge clk) begin
        if(we_b) begin
            mem[addr_b] <= data_inb;
            else begin
                data_outb <= mem[addr_b];
            end
        end
    end



endmodule