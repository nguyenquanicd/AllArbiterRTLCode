//-------------------------------------------
//Author  : Nguyen Hung Quan
//Website : https://nguyenquanicd.blogspot.com/
//Date    : 2019.Aug.15
//Function: Fixed priority Arbiter with the request lockIn
//  - req[0] has highest priority.
//  - A source which has a granted request, can lock the current grant
//    and continue being accepted for the next requests
//-------------------------------------------

module ArbFixedPriorityLocked (
  clk,
  rst_n,
  req,
  lockIn,
  lockSta,
  grant
  );
  parameter REQ_NUM = 4;
  //
  input  clk;
  input  rst_n;
  input  [REQ_NUM-1:0] req;
  input  [REQ_NUM-1:0] lockIn;
  output reg [REQ_NUM-1:0] grant;
  output wire lockSta;
  //
  reg [REQ_NUM-1:0] nextGrant;
  reg [REQ_NUM-1:0] lockReg;
  wire noGrant;
  wire noLock;
  //
  assign noGrant = ~|grant[REQ_NUM-1:0];
  //
  //Grant logic
  //
  generate
    genvar i;
	  //For req[0]
	  always @ (*) begin
      if (lockReg[0])
	      nextGrant[0] = req[0];
      else if (noLock & noGrant)
	      nextGrant[0] = req[0]; //highest priority, do not care other requests
	    else
	      nextGrant[0] = req[0] & grant[0];
    end
	  //For req[REQ_NUM-1:1]
	  for (i = 1; i < REQ_NUM; i=i+1) begin: uGrant
      always @ (*) begin
        if (lockReg[i])
	        nextGrant[i] = req[i];
        else if (noLock & noGrant)
	        nextGrant[i] = req[i] & ~|req[i-1:0]; //low priority, must care higher priority
	  	  else
	  	    nextGrant[i] = req[i] & grant[i];
      end
	  end //for loop
  endgenerate
  always @ (posedge clk, negedge rst_n) begin
    if (~rst_n)
      grant[REQ_NUM-1:0] <= {REQ_NUM{1'b0}};
    else
      grant[REQ_NUM-1:0] <= nextGrant[REQ_NUM-1:0];
  end
  //
  //Lock logic - Set lockReg[i] when lockIn[i]=1 and grant[i]=1
  //
  generate
    genvar j;
	  //
	  for (j = 0; j < REQ_NUM; j=j+1) begin: uLock
	  //
      always @ (posedge clk, negedge rst_n) begin
        if (~rst_n)
	        lockReg[j] <= 1'b0;
	      else if (nextGrant[j] & noLock)
	        lockReg[j] <= lockIn[j];
		    else if (lockReg[j])
          lockReg[j] <= lockIn[j];
        else
		      lockReg[j] <= 1'b0;
      end
	  end //for loop
  endgenerate
  //
  assign lockSta = |lockReg[REQ_NUM-1:0];
  assign noLock  = ~|(lockReg[REQ_NUM-1:0] & lockIn[REQ_NUM-1:0]);
  //
  //
endmodule //ArbFixedPriorityLocked