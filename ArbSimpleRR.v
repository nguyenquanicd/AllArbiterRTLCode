//-------------------------------------------
//Author:  Nguyen Hung Quan
//Website: http://nguyenquanicd.blogspot.com/
//Date    : 2019.Aug.22
//Function: Simple Round Robin (RR) Arbiter
//  - Only use a counter to share access right
//  - One request source, one time slice/slot
//-------------------------------------------
module ArbSimpleRR (
  clk,
  rst_n,
  req,
  grant
  );
  parameter REQ_NUM    = 4;
  parameter COUNTER_W  = clog2(REQ_NUM);
  //
  input  clk;
  input  rst_n;
  input  [REQ_NUM-1:0] req;
  output reg [REQ_NUM-1:0] grant;
  //
  reg [COUNTER_W-1:0] rrCounter;
  wire noGrant;
  //
  assign noGrant    = ~|grant[REQ_NUM-1:0];
  //
  always @ (posedge clk, negedge rst_n) begin
    if (~rst_n)
	    rrCounter[COUNTER_W-1:0] <= {COUNTER_W{1'b0}}; 
	  else if (noGrant) begin
	    if (rrCounter[COUNTER_W-1:0] == REQ_NUM-1)
	      rrCounter[COUNTER_W-1:0] <= {COUNTER_W{1'b0}};
	    else
	      rrCounter[COUNTER_W-1:0] <= rrCounter[COUNTER_W-1:0] + 1'b1;
	  end
  end
  //
  //Create grant
  generate
    genvar i;
    //
	  for (i = 0; i < REQ_NUM; i=i+1) begin: uGrant
      always @ (posedge clk, negedge rst_n) begin
        if (~rst_n)
	      grant[i] <= 1'b0;
	    else if (noGrant)
	      grant[i] <= req[i] & (rrCounter[COUNTER_W-1:0] == i);
      else
        grant[i] <= req[i] & grant[i];
      end
	  end //for loop
  endgenerate
  //
  //
  function integer clog2; 
    input integer value; 
    integer i; 
    begin 
      clog2 = 0; 
      for(i = 0; 2**i < value; i = i + 1) 
        clog2 = i + 1; 
      end 
  endfunction
endmodule //ArbSimpleRR