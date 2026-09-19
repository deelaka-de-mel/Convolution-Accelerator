module pipelined_cpu_2 (
    input  logic        clk, reset,
    output logic [7 :0] imem_addr,  dmem_addr,
    input  logic [15:0] imem_rdata, dmem_rdata,
    output logic [15:0] dmem_wdata,
    output logic        dmem_wen
);
    // Opcode Enumeration
    typedef enum logic [3:0] {
        LOAD  = 4'h0, 
        STORE = 4'h1, 
        MOVE  = 4'h2, 
        ADD   = 4'h3, 
        SUB   = 4'h4, 
        MUL   = 4'h5, 
        JNZ   = 4'h6
    } opcode_t;

    // Architectural Register File
    logic [15:0] regs [16];

    // --- PIPELINE REGISTERS & WIRES ---

    // 1. IF/ID Stage
    logic [7:0]  pc;
    logic [15:0] if_id_ir;

    // ID Stage Wires
    opcode_t     opcode_id;
    logic [3:0]  i_reg_id, i_rs1_id, i_rs2_id, i_rd_id;
    logic [7:0]  addr_id;
    logic [15:0] rd_data1, rd_data2, reg_data_source;

    // 2. ID/EX Stage Registers
    opcode_t     opcode_ex;
    logic [3:0]  i_reg_ex, i_rd_ex;
    logic [7:0]  addr_ex;
    logic [15:0] reg1_ex, reg2_ex;
    logic [15:0] alu_result_ex;

    // 3. EX/MEM Stage Registers
    opcode_t     opcode_mem;
    logic [3:0]  i_reg_mem, i_rd_mem;
    logic [7:0]  addr_mem;
    logic [15:0] alu_result_mem, reg2_mem;

    // 4. MEM/WB Stage Registers
    opcode_t     opcode_wb;
    logic [3:0]  i_rd_wb, i_reg_wb;
    logic [15:0] mem_wb_data;


    // STAGE 1: FETCH (IF)    
    always_comb begin
        imem_addr = pc;
    end

    // STAGE 2: DECODE (ID)
    always_comb begin
        // Extract opcode
        opcode_id = opcode_t'(if_id_ir[3:0]);
        
        // Format A: Load, Store, JNZ ({addr[7:0], i_reg[3:0], opcode[3:0]})
        addr_id  = if_id_ir[15:8];
        i_reg_id = if_id_ir[7:4];
        
        // Format B: Move, Add, Sub, Mul ({i_rs2[3:0], i_rs1[3:0], i_rd[3:0], opcode[3:0]})
        i_rd_id  = if_id_ir[7:4];
        i_rs1_id = if_id_ir[11:8];
        i_rs2_id = if_id_ir[15:12];

        // Register File Lookups
        rd_data1        = regs[i_rs1_id];
        rd_data2        = regs[i_rs2_id];
        reg_data_source = regs[i_reg_id];
    end

    // STAGE 3: EXECUTE (EX) - ALU & Branch Logic
    always_comb begin
        case (opcode_ex)
            ADD:  alu_result_ex = reg1_ex + reg2_ex;
            SUB:  alu_result_ex = reg1_ex - reg2_ex;
            MUL:  alu_result_ex = reg1_ex * reg2_ex;
            MOVE: alu_result_ex = reg1_ex;
            default: alu_result_ex = '0;
        endcase
    end

    // STAGE 4: MEMORY (MEM)
    always_comb begin
        dmem_addr  = addr_mem;
        dmem_wdata = reg2_mem;
        dmem_wen   = (opcode_mem == STORE);
    end


    // ==========================================
    // SEQUENTIAL CLOCK LOGIC (Pipeline Registers & Updates)
    // ==========================================
    always_ff @(posedge clk) begin
        if (reset) begin
            pc           <= '0;
            if_id_ir     <= '0;
            
            opcode_ex    <= LOAD;
            i_reg_ex     <= '0;
            i_rd_ex      <= '0;
            addr_ex      <= '0;
            reg1_ex      <= '0;
            reg2_ex      <= '0;

            opcode_mem   <= LOAD;
            i_reg_mem    <= '0;
            i_rd_mem     <= '0;
            addr_mem     <= '0;
            alu_result_mem <= '0;
            reg2_mem     <= '0;

            opcode_wb    <= LOAD;
            i_rd_wb      <= '0;
            i_reg_wb     <= '0;
            mem_wb_data  <= '0;

            for (int i = 0; i < 16; i++) begin
                regs[i] <= '0;
            end
        end else begin
            
            // --- IF Stage Step ---
            pc       <= pc + 1'b1;
            if_id_ir <= imem_rdata;

            // --- ID to EX Pipeline Handoff ---
            opcode_ex <= opcode_id;
            i_reg_ex  <= i_reg_id;
            i_rd_ex   <= i_rd_id;
            addr_ex   <= addr_id;
            reg1_ex   <= rd_data1;
            // Route correct data operand for STORE/JNZ vs standard R-type
            reg2_ex   <= (opcode_id == LOAD || opcode_id == STORE || opcode_id == JNZ) ? reg_data_source : rd_data2;

            // --- EX to MEM Pipeline Handoff ---
            opcode_mem     <= opcode_ex;
            i_reg_mem      <= i_reg_ex;
            i_rd_mem       <= i_rd_ex;
            addr_mem       <= addr_ex;
            alu_result_mem <= alu_result_ex;
            reg2_mem       <= reg2_ex;

            // Branch Evaluation and Control Hazard Flushing
            if (opcode_ex == JNZ && reg2_ex != '0) begin
                pc       <= addr_ex;
                if_id_ir <= '0; // Flush fetched instruction on taken branch
            end

            // --- MEM to WB Pipeline Handoff ---
            opcode_wb <= opcode_mem;
            i_rd_wb   <= i_rd_mem;
            i_reg_wb  <= i_reg_mem;
            
            if (opcode_mem == LOAD)
                mem_wb_data <= dmem_rdata; //no operation needed
            else
                mem_wb_data <= alu_result_mem;

            // --- WRITEBACK STAGE ---
            case (opcode_wb)
                LOAD:  regs[i_reg_wb] <= mem_wb_data;
                MOVE, 
                ADD, 
                SUB, 
                MUL:   regs[i_rd_wb]  <= mem_wb_data;
                default: ;
            endcase
        end
    end

endmodule