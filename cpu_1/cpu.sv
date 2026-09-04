module cpu (
  input  logic        clk, reset,
  output logic [7 :0] imem_addr,  dmem_addr,
  input  logic [15:0] imem_rdata, dmem_rdata,
  output logic [15:0] dmem_wdata,
  output logic        dmem_wen
);
  logic [7:0] pc, addr;
  enum logic [3:0] {LOAD, STORE, MOVE, ADD, SUB, MUL, JNZ} opcode;
  logic [ 3:0] i_rs1, i_rs2, i_rd, i_reg;
  logic [15:0] regs [16];
  logic [15:0] reg_1, reg_2;

  always_comb begin
    imem_addr = pc;
    {addr        , i_reg, opcode} = imem_rdata;
    {i_rs2, i_rs1, i_rd , opcode} = imem_rdata;

    dmem_addr  = addr;
    dmem_wdata = regs[i_reg];
    dmem_wen   = opcode == STORE;

    reg_1      = regs[i_rs1];
    reg_2      = regs[i_rs2];
  end

  always_ff @(posedge clk)
    if (reset) begin
      pc   <= '0;
      for (int i = 0; i < 16; i++) regs[i] <= '0;
    end else begin
      pc   <= pc + 1'b1;

      case (opcode)
        LOAD: regs[i_reg] <= dmem_rdata;
        MOVE: regs[i_rd ] <= reg_1;
        ADD : regs[i_rd ] <= reg_1 + reg_2;
        SUB : regs[i_rd ] <= reg_1 - reg_2;
        MUL : regs[i_rd ] <= reg_1 * reg_2;
        JNZ : if (regs[i_reg] != '0) pc <= addr;
        default: ;
      endcase
    end
endmodule
