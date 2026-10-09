module soc_top (
    input         CLOCK_50,
    input  [3:0]  KEY,
    output [17:0] LEDR,
    output [8:0]  LEDG,
    output [6:0]  HEX0, // Ones digit
    output [6:0]  HEX1, // Tens digit
    output [6:0]  HEX2, // Hundreds digit
	 output [7:0]  LCD_DATA,
	 output        LCD_EN, LCD_RS, LCD_RW, LCD_ON, LCD_BLON
);

    // -------------------------------------------------------------
    // 1. Clock & Reset Management
    // -------------------------------------------------------------
    wire clk, locked;
    pll u_pll (
        .inclk0(CLOCK_50),
        .c0(clk),
        .locked(locked)
    );

    // Reset: asserts asynchronously, releases synchronously (2-FF)
    wire rst_in_n = locked & KEY[0];
    reg [1:0] rst_sync = 2'b00;
    always @(posedge clk or negedge rst_in_n) begin
        if (!rst_in_n) rst_sync <= 2'b00;
        else           rst_sync <= {rst_sync[0], 1'b1};
    end
    wire resetn = rst_sync[1];
	 
	


    // -------------------------------------------------------------
    // 2. PicoRV32 RISC-V CPU Core
    // -------------------------------------------------------------
    wire        mem_valid, mem_instr, trap;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0]  mem_wstrb;
    wire        mem_ready;
    wire [31:0] mem_rdata;

    picorv32 #(
        .PROGADDR_RESET     (32'h0000_0000),
        .STACKADDR          (32'h0000_4000),
        .TWO_CYCLE_ALU      (1),
        .TWO_CYCLE_COMPARE  (1),
        .BARREL_SHIFTER     (0),
        .ENABLE_MUL         (0),
        .ENABLE_DIV         (0),
        .ENABLE_IRQ         (0),
        .ENABLE_COUNTERS    (1),
        .COMPRESSED_ISA     (0)
    ) cpu (
        .clk        (clk),
        .resetn     (resetn),
        .trap       (trap),
        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_ready  (mem_ready),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_rdata  (mem_rdata)
    );

    // -------------------------------------------------------------
    // 3. Address Decode (High Nibble Only)
    // -------------------------------------------------------------
    wire sel_ram = mem_valid && (mem_addr[31:28] == 4'h0); // 0x0000_0000 (16 KB RAM)
    wire sel_led = mem_valid && (mem_addr[31:28] == 4'h1); // 0x1000_0000 (LEDs)
    wire sel_csr = mem_valid && (mem_addr[31:28] == 4'h2); // 0x2000_0000 (CSRs)
    wire sel_img = mem_valid && (mem_addr[31:28] == 4'h3); // 0x3000_0000 (Image RAM)
    wire sel_hex = mem_valid && (mem_addr[31:28] == 4'h4); // 0x4000_0000 (7-Seg Display)
	 
	 
	 wire sel_uart = mem_valid && (mem_addr[31:28] == 4'h5);
	 wire sel_lcd  = mem_valid && (mem_addr[31:28] == 4'h6);

    // -------------------------------------------------------------
    // 4. 16 KB Firmware RAM (Four 8-bit Lanes, 4096 Words)
    // -------------------------------------------------------------
    (* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram0 [0:4095];
    (* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram1 [0:4095];
    (* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram2 [0:4095];
    (* ramstyle = "M9K, no_rw_check" *) reg [7:0] ram3 [0:4095];

    reg [31:0] ram_init [0:4095];
    integer i;
    initial begin
        $readmemh("firmware.hex", ram_init);
        for (i = 0; i < 4096; i = i + 1) begin
            ram0[i] = ram_init[i][ 7: 0];
            ram1[i] = ram_init[i][15: 8];
            ram2[i] = ram_init[i][23:16];
            ram3[i] = ram_init[i][31:24];
        end
    end

    wire [11:0] ram_addr = mem_addr[13:2];
    wire        ram_en   = sel_ram && !ram_ready;
    reg  [7:0]  rd0, rd1, rd2, rd3;
    reg         ram_ready = 1'b0;

    always @(posedge clk) ram_ready <= ram_en;

    always @(posedge clk) if (ram_en) begin
        if (mem_wstrb[0]) ram0[ram_addr] <= mem_wdata[7:0];
        rd0 <= ram0[ram_addr];
    end

    always @(posedge clk) if (ram_en) begin
        if (mem_wstrb[1]) ram1[ram_addr] <= mem_wdata[15:8];
        rd1 <= ram1[ram_addr];
    end

    always @(posedge clk) if (ram_en) begin
        if (mem_wstrb[2]) ram2[ram_addr] <= mem_wdata[23:16];
        rd2 <= ram2[ram_addr];
    end

    always @(posedge clk) if (ram_en) begin
        if (mem_wstrb[3]) ram3[ram_addr] <= mem_wdata[31:24];
        rd3 <= ram3[ram_addr];
    end

    wire [31:0] ram_rdata = {rd3, rd2, rd1, rd0};

    // -------------------------------------------------------------
    // 5. LED Register at 0x1000_0000
    // -------------------------------------------------------------
    reg [7:0] led_reg = 8'h00;
    reg led_ready = 1'b0;

    always @(posedge clk) begin
        led_ready <= 1'b0;
        if (sel_led && !led_ready) begin
            led_ready <= 1'b1;
            if (mem_wstrb[0]) led_reg <= mem_wdata[7:0];
        end
    end
    wire [31:0] led_rdata = {24'b0, led_reg};

    // -------------------------------------------------------------
    // 6. Fake Accelerator Registers at 0x2000_0000
    // -------------------------------------------------------------
    wire [31:0] csr_rdata;
    wire        csr_ready;

    conv_accel_regs_fake accel_fake_inst (
        .clk       (clk),
        .rst_n     (resetn),
        .sel       (sel_csr),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (csr_rdata),
        .mem_ready (csr_ready)
    );

    // -------------------------------------------------------------
    // 7. Image Memory Block at 0x3000_0000
    // -------------------------------------------------------------
    wire [31:0] img_rdata;
    wire        img_ready;

    image_ram img_ram_inst (
        .clk       (clk),
        .sel       (sel_img),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (img_rdata),
        .mem_ready (img_ready)
    );

   // -------------------------------------------------------------
    // 8. 7-Segment Display Peripheral at 0x4000_0000
    // -------------------------------------------------------------
    reg [7:0] hex_reg = 8'h00; // Stores pixel value (0 - 255)
    reg hex_ready = 1'b0;

    always @(posedge clk) begin
        hex_ready <= 1'b0;
        if (sel_hex && !hex_ready) begin
            hex_ready <= 1'b1;
            if (mem_wstrb[0]) hex_reg <= mem_wdata[7:0];
        end
    end
    wire [31:0] hex_rdata = {24'b0, hex_reg};

    // Calculate Decimal Digits (0 - 255)
    wire [3:0] hundreds_digit = hex_reg / 100;
    wire [3:0] tens_digit     = (hex_reg / 10) % 10;
    wire [3:0] ones_digit     = hex_reg % 10;

    // Connect Decoders
    hex_decoder dec_ones (.hex_digit(ones_digit),     .seg(HEX0)); // Ones (e.g. '8')
    hex_decoder dec_tens (.hex_digit(tens_digit),     .seg(HEX1)); // Tens (e.g. '7')
    hex_decoder dec_hundreds (.hex_digit(hundreds_digit), .seg(HEX2)); // Hundreds (e.g. '1')
	 
       // -------------------------------------------------------------
    // 9. UART (0x5000_0000), LCD (0x6000_0000), Bus Mux
    // -------------------------------------------------------------
    wire [31:0] uart_rdata, lcd_rdata;
    wire        uart_ready, lcd_ready;

    jtag_uart_periph u_uart (
        .clk(clk), .resetn(resetn), .sel(sel_uart),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(uart_rdata), .mem_ready(uart_ready));

    lcd_reg u_lcd (
        .clk(clk), .sel(sel_lcd), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(lcd_rdata), .mem_ready(lcd_ready),
        .LCD_DATA(LCD_DATA), .LCD_EN(LCD_EN), .LCD_RS(LCD_RS),
        .LCD_RW(LCD_RW), .LCD_ON(LCD_ON), .LCD_BLON(LCD_BLON));

    assign mem_ready = ram_ready | led_ready | csr_ready | img_ready | hex_ready
                     | uart_ready | lcd_ready;

    assign mem_rdata = ram_ready  ? ram_rdata  :
                       led_ready  ? led_rdata  :
                       csr_ready  ? csr_rdata  :
                       img_ready  ? img_rdata  :
                       hex_ready  ? hex_rdata  :
                       uart_ready ? uart_rdata :
                       lcd_ready  ? lcd_rdata  : 32'h0;

    assign LEDG = {1'b0, led_reg};
    assign LEDR = {17'b0, trap};
endmodule


// Helper Module: 4-bit Hex to 7-Segment Decoder (Active-Low)
module hex_decoder (
    input  wire [3:0] hex_digit,
    output reg  [6:0] seg
);
    always_comb begin
        case (hex_digit)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0010010;
            4'h3: seg = 7'b0000110;
            4'h4: seg = 7'b1001100;
            4'h5: seg = 7'b0100100;
            4'h6: seg = 7'b0100000;
            4'h7: seg = 7'b0001111;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0000100;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111;
        endcase
    end
endmodule