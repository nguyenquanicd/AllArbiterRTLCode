//-------------------------------------------
//Author  : Nguyen Hung Quan
//Website : https://nguyenquanicd.blogspot.com/
//Date    : 2019.Aug.15
//Function: Priority Round Robin (RR) Arbiter
//  - Use a counter to share access right
//  - Can allocate the grant to a request source
//    outside its time slice/slot
//-------------------------------------------
module ArbBalanceRR (
  clk,
  rst_n,
  req,
  grant
  );
  //
  parameter REQ_NUM    = 4;
  parameter COUNTER_W  = clog2(REQ_NUM);
  //
  input  clk;
  input  rst_n;
  input  [REQ_NUM-1:0] req;
  output reg [REQ_NUM-1:0] grant;
  //Internal signals
  reg [REQ_NUM*COUNTER_W-1:0] pReg;
  wire [REQ_NUM*COUNTER_W-1:0] cPriorityLevel;
  wire [REQ_NUM*REQ_NUM-1:0] levelReq;
  wire [REQ_NUM-1:0] orAssertedReq;
  wire [REQ_NUM-1:0] reqEn;
  wire [REQ_NUM*REQ_NUM-1:0] newGrant;
  wire [REQ_NUM-1:0] finalNewGrant;
  wire [REQ_NUM-1:0] nextGrant;
  wire noGrant;
  wire updateP;
  //Update the priority level
  //Update the priority registers when noGrant=1 and
  //at least, one request is asserted.
  assign updateP = noGrant & (|req[REQ_NUM-1:0]);
  //-----------------------------------------------------------
  //(1) PRIORITY LEVEL REGISTER
  // One request source has one priority level register
  //    with COUNTER_W bits
  // Change to REQ_NUM-1 (lowest priority) if it is the current grant
  // Minus 1 if it is not the current grant
  //-----------------------------------------------------------
  generate
    genvar i0;
    assign cPriorityLevel[COUNTER_W-1:0] = 
           nextGrant[0]? 
           pReg[COUNTER_W-1:0]: 
           {COUNTER_W{1'b0}};
    for (i0 = 1; i0 < REQ_NUM; i0 = i0+1) begin: cPValue
      assign cPriorityLevel[COUNTER_W*(i0+1)-1:i0*COUNTER_W]
             = nextGrant[i0]?
             pReg[COUNTER_W*(i0+1)-1:i0*COUNTER_W]
             : cPriorityLevel[COUNTER_W*i0-1:(i0-1)*COUNTER_W];
    end
  endgenerate
  //
  generate
    genvar i;
	  for (i = 0; i < REQ_NUM; i = i+1) begin: pRegGen
	    always @ (posedge clk, negedge rst_n) begin
	      if (~rst_n)
		    pReg[COUNTER_W*(i+1)-1:i*COUNTER_W] <= i;
		  //Set to lowest priority level after granting
		  else if (updateP) begin
		    if (nextGrant[i])
		      pReg[COUNTER_W*(i+1)-1:i*COUNTER_W] <= REQ_NUM - 1;
		    else if (pReg[COUNTER_W*(i+1)-1:i*COUNTER_W]
        >= cPriorityLevel[COUNTER_W*REQ_NUM-1:(REQ_NUM-1)*COUNTER_W])
		    //Increase the higher priority level by minusing 1
		    //if the current priority level is different from 0 
		      pReg[COUNTER_W*(i+1)-1:i*COUNTER_W] <= 
          pReg[COUNTER_W*(i+1)-1:i*COUNTER_W] - 1;
	      end
	    end
	  end
  endgenerate
  //-----------------------------------------------------------
  //(2) PRIORITY SELECTION
  // Map a request with the current priority.
  // One input request is mapped to a REQ_NUM-bit group of levelReq
  //-----------------------------------------------------------
  generate
    genvar j0;
	  genvar j1;
	  for (j0=0; j0 < REQ_NUM; j0=j0+1) begin: reqSel
	    for (j1=0; j1 < REQ_NUM; j1=j1+1) begin: selOut
	      //levelReq[*] is asserted if req[j0]
        //asserted and the priority level is mapped
	      assign levelReq[j0*REQ_NUM+j1] =
        req[j0] & 
        (pReg[COUNTER_W*(j0+1)-1:j0*COUNTER_W] == j1); 
	    end
	  end
  endgenerate
  //-----------------------------------------------------------
  //(3) ASSERTED REQUEST CHECK
  // Check "what priority level has the asserted request?"
  //-----------------------------------------------------------
  generate
    genvar k0;
	  for (k0=0; k0 < REQ_NUM; k0=k0+1) begin: AChk
	    assign orAssertedReq[k0] = 
      orOut(levelReq[REQ_NUM*REQ_NUM-1:0],k0);
	  end
  endgenerate
  //-----------------------------------------------------------
  //(4) REQUEST ENABLE
  // Create the enable signal to determine the request which
  // is the highest priority. Only one priority level is enabled
  // and it is the highest priority.
  //-----------------------------------------------------------
  generate
    genvar k1;
	  assign reqEn[0] = orAssertedReq[0];
	  for (k1=1; k1 < REQ_NUM; k1=k1+1) begin: ReqEnable
	    assign reqEn[k1] = orAssertedReq[k1] &
      ~|orAssertedReq[k1-1:0];
	  end
  endgenerate
  //-----------------------------------------------------------
  //(5) REQUEST MASK
  // Mask a request by enable signal.
  // Only one request is asserted.
  //-----------------------------------------------------------
  generate
    genvar k2a;
	  genvar k2b;
	  for (k2a=0; k2a<REQ_NUM; k2a=k2a+1) begin: ReqMask
	    for (k2b=0; k2b<REQ_NUM; k2b=k2b+1) begin: BitMask
	      assign newGrant[k2b+k2a*REQ_NUM] = levelReq[k2b+k2a*REQ_NUM] & reqEn[k2b];
	    end
	  end
  endgenerate
  //-----------------------------------------------------------
  //(6) NEXT GRANT
  // Logic for the new arbitration to create a new grant.
  //-----------------------------------------------------------
  generate
    genvar k3;
	  for (k3=0; k3 < REQ_NUM; k3=k3+1) begin: FNewGrant
	    assign finalNewGrant[k3] = |newGrant[REQ_NUM*(k3+1)-1:k3*REQ_NUM];
	  end
  endgenerate
  assign noGrant = ~|grant[REQ_NUM-1:0];
  assign nextGrant[REQ_NUM-1:0] = noGrant? finalNewGrant[REQ_NUM-1:0]: grant[REQ_NUM-1:0] & req[REQ_NUM-1:0];
  //-----------------------------------------------------------
  //(7) and GRANT register
  //-----------------------------------------------------------
  always @ (posedge clk, negedge rst_n) begin
    if (~rst_n)
      grant[REQ_NUM-1:0] <= {REQ_NUM{1'b0}};
    else
      grant[REQ_NUM-1:0] <= nextGrant[REQ_NUM-1:0];
  end
  //-----------------------------------------------------------
  //OR function - Can synthesize
  //-----------------------------------------------------------
  function reg orOut;
    input [REQ_NUM*REQ_NUM-1:0] orIn;
	input integer id;
	integer i;
    begin
      orOut = 1'b0;
      for (i=0; i<REQ_NUM; i=i+1) begin
        orOut = orOut | orIn[id+i*REQ_NUM];
      end
    end
  endfunction
  //-----------------------------------------------------------
  //log2 function - Not for synthesizing
  //Only use to calculate the parameter value
  //-----------------------------------------------------------
  function integer clog2; 
    input integer value; 
	  integer i;
    begin 
      clog2 = 0;
      for(i = 0; 2**i < value; i = i + 1) 
        clog2 = i + 1; 
      end
  endfunction
  //
endmodule
