module jtag_uart_periph (
    input  logic        clk,
    input  logic        resetn,
    input  logic        sel,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [3:0]  mem_wstrb,
    output logic [31:0] mem_rdata,
    output logic        mem_ready
);
    typedef enum logic [1:0] {IDLE, ACC, DONE} st_t;
    st_t st = IDLE;

    logic        a_r = 0, wr_r = 0;
    logic [31:0] wdat = 0;
    wire  [31:0] rdata;
    wire         wait_rq;

    initial begin mem_ready = 1'b0; mem_rdata = 32'b0; end

    always_ff @(posedge clk) begin
        mem_ready <= 1'b0;
        case (st)
            IDLE: if (sel) begin
                a_r  <= mem_addr[2];
                wr_r <= |mem_wstrb;
                wdat <= mem_wdata;
                st   <= ACC;
            end
            ACC: if (!wait_rq) begin
                mem_rdata <= rdata;
                mem_ready <= 1'b1;
                st        <= DONE;
            end
            DONE: st <= IDLE;
            default: st <= IDLE;
        endcase
    end

    wire acc = (st == ACC);

        jtag_uart_ip u_jtag (
        .clk_clk                                   (clk),
        .reset_reset_n                             (resetn),
        .jtag_uart_0_avalon_jtag_slave_chipselect  (acc),
        .jtag_uart_0_avalon_jtag_slave_address     (a_r),
        .jtag_uart_0_avalon_jtag_slave_read_n      (~(acc & ~wr_r)),
        .jtag_uart_0_avalon_jtag_slave_write_n     (~(acc &  wr_r)),
        .jtag_uart_0_avalon_jtag_slave_writedata   (wdat),
        .jtag_uart_0_avalon_jtag_slave_readdata    (rdata),
        .jtag_uart_0_avalon_jtag_slave_waitrequest (wait_rq)
    );
endmodule