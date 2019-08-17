//-------------------------------------------
//Author:  Nguyen Hung Quan
//Website: http://nguyenquanicd.blogspot.com/
//Date    : 2019.Aug.15
//Function: Absolute Fixed priority Arbiter.
//  - req[0] has highest priority
//  - High request can occupy grant of lower request anywhen
//-------------------------------------------
module ArbFixedPriorityAbs (
  clk,
  rst_n,
  req,
  grant
  );
  parameter REQ_NUM = 4;
  //
  input  clk;
  input  rst_n;
  input  [REQ_NUM-1:0] req;
  output reg [REQ_NUM-1:0] grant;
  //
  generate
    genvar i;
	  //For req[0]
	  always @ (posedge clk, negedge rst_n) begin
      if (~rst_n)
	      grant[0] <= 1'b0;
	    else
	      grant[0] <= req[0]; //highest priority, do not care other requests
    end
	  //For req[REQ_NUM-1:1]
	  for (i = 1; i < REQ_NUM; i=i+1) begin: uGrant
      always @ (posedge clk, negedge rst_n) begin
        if (~rst_n)
	        grant[i] <= 1'b0;
	      else
	        grant[i] <= req[i] & ~|req[i-1:0]; //low priority, must care higher priority
      end
	  end //for loop
  endgenerate
  //
endmodule //ArbFixedPriorityAbs
