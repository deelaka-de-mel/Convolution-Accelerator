module lcd_reg (
    input  logic        clk,
    input  logic        sel,
    input  logic [31:0] mem_wdata,
    input  logic [3:0]  mem_wstrb,
    output logic [31:0] mem_rdata,
    output logic        mem_ready,
    output logic [7:0]  LCD_DATA,
    output logic        LCD_EN, LCD_RS, LCD_RW, LCD_ON, LCD_BLON
);
    reg [9:0] r = 10'd0;
    initial mem_ready = 1'b0;

    always_ff @(posedge clk) begin
        mem_ready <= sel && !mem_ready;
        if (sel && !mem_ready) begin
            if (mem_wstrb[0]) r[7:0] <= mem_wdata[7:0];
            if (mem_wstrb[1]) r[9:8] <= mem_wdata[9:8];
        end
    end

    assign mem_rdata = {22'b0, r};
    assign LCD_DATA = r[7:0];
    assign LCD_RS   = r[8];
    assign LCD_EN   = r[9];
    assign LCD_RW   = 1'b0;
    assign LCD_ON   = 1'b1;
    assign LCD_BLON = 1'b1;
endmodule