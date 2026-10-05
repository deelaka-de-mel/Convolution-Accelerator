module mac_unit (
    input  logic        clk,
    input  logic        rst_n,
    input  logic         clear,
    input  logic         enable,
    input  logic  [7:0]  pixel,
    input  logic signed [7:0]  weight,
    output logic signed [20:0] acc
);

	 logic signed [15:0] product;

    always_comb begin
        product = $signed({1'b0, pixel}) * weight;	//convert pixel to signed format before multiplying with weight
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            acc <= '0;
        else if (clear)
            acc <= '0;
        else if (enable)
            acc <= acc + $signed({{5{product[15]}}, product});
    end

endmodule