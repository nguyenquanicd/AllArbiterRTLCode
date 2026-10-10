//-------------------------------------------
//Author:  Nguyen Hung Quan
//Website: http://nguyenquanicd.blogspot.com/
//Date    : 2019.Aug.22
//Update  : 2026.Oct.10 - COUNTER_W is a localparam, REQ_NUM=1 is legal,
//          lint clean (width compare, hidden variable)
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
  //Derived constants (do not override)
  localparam COUNTER_W = clog2(REQ_NUM);
  localparam [31:0] LAST_32 = REQ_NUM-1;
  localparam [COUNTER_W-1:0] LAST = LAST_32[COUNTER_W-1:0];   //last counter value
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
	    if (rrCounter[COUNTER_W-1:0] == LAST)
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
  //-----------------------------------------------------------
  //ceil(log2(value)) with a minimum of 1, so REQ_NUM=1 does not create
  //a zero-width (reversed range) vector.
  //Not for synthesizing - only used to calculate constants
  //-----------------------------------------------------------
  function integer clog2;
    input integer value;
    integer ii;
    begin
      clog2 = 1;
      for (ii = 0; 2**ii < value; ii = ii + 1)
        clog2 = ii + 1;
    end
  endfunction
endmodule //ArbSimpleRR