module mac_unit_tb;

	logic clk,rst_n,clear,enable;
	logic [7:0] pixel;
	logic signed [7:0] weight;
	logic signed [19:0] acc;
	
	
	mac_unit dut (
		.clk(clk),
		.rst_n(rst_n),
		.clear(clear),
		.enable(enable),
		.pixel(pixel),
		.weight(weight),
		.acc(acc));
		
		
	
	initial clk = 0;
	always #5 clk = ~clk;
	
	initial begin
	
		  rst_n  = 0;
        clear  = 0;
        enable = 0;
        pixel  = 0;
        weight = 0;
		
		  @(posedge clk);
		  rst_n = 1;
		  
		  @(posedge clk);
		  clear = 1; enable = 0;
		  
		  @(posedge clk);
		  clear = 0; enable = 1;
		  weight = -8'sd1 ; pixel = 8'd30;
		  
		  @(posedge clk);
		  weight = 8'sd1 ; pixel = 8'd10;
		  
		  @(posedge clk);
		  weight = 8'sd1 ; pixel = 8'd20;
		  
	 $finish;
	 
	 end
		  
endmodule
	