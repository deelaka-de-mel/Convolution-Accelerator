module pipelined_cpu(
    input  logic        clk, reset,
    output logic [7 :0] imem_addr,  dmem_addr,
    input  logic [15:0] imem_rdata, dmem_rdata,
    output logic [15:0] dmem_wdata,
    output logic        dmem_wen
);
    logic [7:0] pc;
    enum logic [3:0] {LOAD, STORE, MOVE, ADD, SUB, MUL, JNZ} opcode_if, opcode_id, opcode_ex, opcode_mem, opcode_wb;
    logic [3:0] i_rs1, i_rs2, i_rd, i_reg;
    logic [15:0] regs [16];

    // Registers 

    logic [15:0] if_id_ir;
    
    // ID/EX Stage Registers
    logic [3:0]  id_ex_opcode, id_ex_rd, id_ex_reg;
    logic [7:0]  id_ex_addr;
    logic [15:0] id_ex_reg1, id_ex_reg2;

    // EX/MEM Stage Registers
    logic [3:0]  ex_mem_opcode, ex_mem_reg;
    logic [7:0]  ex_mem_addr;
    logic [15:0] ex_mem_alu_result, ex_mem_reg2;

    // MEM/WB Stage Registers
    logic [3:0]  mem_wb_opcode, mem_wb_rd, mem_wb_reg;
    logic [15:0] mem_wb_data;

    // --- FETCH STAGE ---
    always_comb begin
        imem_addr = pc;
    end

    // --- DECODE STAGE SIGNALS ---
    logic [3:0] id_opcode;
    logic [7:0] id_addr;
    logic [3:0] id_reg, id_rs1, id_rs2, id_rd;
    logic [15:0] rd_data1, rd_data2;

    always_comb begin
        id_opcode = if_id_ir[3:0];
        id_addr   = if_id_ir[15:8];
        id_reg    = if_id_ir[7:4];
        id_rs2    = if_id_ir[15:12];
        id_rs1    = if_id_ir[11:8];
        id_rd     = if_id_ir[7:4];

        rd_data1  = regs[id_rs1];
        rd_data2  = regs[id_rs2];
        
        // Memory stage control outputs
        dmem_addr  = ex_mem_addr;
        dmem_wdata = ex_mem_reg2;
        dmem_wen   = (ex_mem_opcode == STORE);
    end

    // --- SEQUENTIAL PIPELINE & EXECUTION ---
    always_ff @(posedge clk) begin
        if (reset) begin
            pc <= '0;
            for (int i = 0; i < 16; i++) regs[i] <= '0;
            if_id_ir <= '0;
            id_ex_opcode <= '0;
            ex_mem_opcode <= '0;
            mem_wb_opcode <= '0;
        end else begin
            // 1. FETCH
            pc <= pc + 1'b1;
            if_id_ir <= imem_rdata;

            // 2. DECODE -> EXECUTE Pipeline Register Update
            id_ex_opcode <= id_opcode;
            id_ex_addr   <= id_addr;
            id_ex_reg    <= id_reg;
            id_ex_rd     <= id_rd;
            id_ex_reg1   <= rd_data1;
            id_ex_reg2   <= rd_data2;

            // 3. EXECUTE -> MEMORY Pipeline Register Update & ALU
            ex_mem_opcode <= id_ex_opcode;
            ex_mem_reg    <= id_ex_reg;
            ex_mem_addr   <= id_ex_addr[7:0];
            ex_mem_reg2   <= id_ex_reg2;
            
            case (id_ex_opcode)
                ADD: ex_mem_alu_result <= id_ex_reg1 + id_ex_reg2;
                SUB: ex_mem_alu_result <= id_ex_reg1 - id_ex_reg2;
                MUL: ex_mem_alu_result <= id_ex_reg1 * id_ex_reg2;
                MOVE: ex_mem_alu_result <= id_ex_reg1;
                default: ex_mem_alu_result <= '0;
            endcase

            // Handle JNZ branch evaluation in EX stage
            if (id_ex_opcode == JNZ && regs[id_ex_reg] != '0) begin
                pc <= id_ex_addr;
                if_id_ir <= '0; // Flush fetch on branch
            end

            // 4. MEMORY -> WRITEBACK Pipeline Register Update
            mem_wb_opcode <= ex_mem_opcode;
            mem_wb_rd     <= id_ex_rd; // pass along destination tags
            mem_wb_reg    <= ex_mem_reg;
            
            if (ex_mem_opcode == LOAD)
                mem_wb_data <= dmem_rdata;
            else
                mem_wb_data <= ex_mem_alu_result;

            // 5. WRITEBACK STAGE (Actual Register File Updates happen here)
            case (mem_wb_opcode)
                LOAD, MOVE, ADD, SUB, MUL: begin
                    regs[mem_wb_rd] <= mem_wb_data; // or mem_wb_reg depending on instruction format
                end
                default: ;
            endcase
        end
    end
endmodule