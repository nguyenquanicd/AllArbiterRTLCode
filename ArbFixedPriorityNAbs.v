//-------------------------------------------
//Author  : Nguyen Hung Quan
//Website : https://nguyenquanicd.blogspot.com/
//Date    : 2019.Aug.15
//Function: Non-absolute Fixed priority Arbiter
//  - req[0] has highest priority
//  - High request can only occupy grant of lower request
//    when the current grant is completed
//-------------------------------------------
module ArbFixedPriorityNAbs (
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
  wire noGrant;
  assign noGrant = ~|grant[REQ_NUM-1:0];
  //
  generate
    genvar i;
	//For req[0]
	  always @ (posedge clk, negedge rst_n) begin
      if (~rst_n)
	      grant[0] <= 1'b0;
	    else if (noGrant)
	      grant[0] <= req[0]; //highest priority, do not care other requests
      else
        grant[0] <= req[0] & grant[0];
    end
	//For req[REQ_NUM-1:1]
	  for (i = 1; i < REQ_NUM; i=i+1) begin: uGrant
      always @ (posedge clk, negedge rst_n) begin
        if (~rst_n)
	        grant[i] <= 1'b0;
	      else if (noGrant)
	        grant[i] <= req[i] & ~|req[i-1:0]; //low priority, must care higher priority
        else
          grant[i] <= req[i] & grant[i];
      end
	  end //for loop
  endgenerate
  //
endmodule //ArbFixedPriorityNAbs