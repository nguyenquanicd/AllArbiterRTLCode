//-------------------------------------------
//Author  : Nguyen Hung Quan
//Website : https://nguyenquanicd.blogspot.com/
//Date    : 2019.Aug.20
//Function: Dynamic priority Arbiter
//  - All requests is arbitrated on its priority level
//  - If priority levels are same, request source of 
//    lower bit is higher priority. req[0] is highest priority. 
//-------------------------------------------
module ArbDynamicPriority (
  clk,
  rst_n,
  req,
  priorityLevel,
  grant
  );
  parameter REQ_NUM    = 4;
  parameter PRI_WIDTH  = clog2(REQ_NUM);
  parameter PRI_TOTALW = REQ_NUM*PRI_WIDTH;
  //
  input  clk;
  input  rst_n;
  input  [REQ_NUM-1:0] req;
  input  [PRI_TOTALW-1:0] priorityLevel;
  output reg [REQ_NUM-1:0] grant;
  //
  wire [REQ_NUM*REQ_NUM-1:0] compResult;
  wire noGrant;
  wire [REQ_NUM-1:0] orPriorityResult;
  wire [REQ_NUM-1:0] reqEn;
  wire [REQ_NUM*REQ_NUM-1:0] newGrant;
  wire [REQ_NUM-1:0] setGrant;
  wire [REQ_NUM-1:0] setPriorityGrant;
  //Priority comparator
  generate
    genvar i0;
    genvar i1;
	  //--------------------------------------
    //(1) Priority selection
    //--------------------------------------
    for (i0 = 0; i0 < REQ_NUM; i0=i0+1) begin: uComp
      for (i1 = 0; i1 < REQ_NUM; i1=i1+1) begin: bitComp
	      assign compResult[i1+i0*REQ_NUM] = req[i0] & (priorityLevel[PRI_WIDTH*(i0+1)-1:PRI_WIDTH*i0] == i1);
	    end
    end
    //--------------------------------------
    //(2) Asserted request check based on the priority level
    //--------------------------------------
    for (i0=0; i0<REQ_NUM; i0=i0+1) begin: AChk
	    assign orPriorityResult[i0] = orOut(compResult[REQ_NUM*REQ_NUM-1:0],i0);
	  end
    //--------------------------------------
    //(3) Request enable
    //--------------------------------------
	  assign reqEn[0] = orPriorityResult[0];
	  for (i0=1; i0<REQ_NUM; i0=i0+1) begin: ReqEnable
	    assign reqEn[i0] = orPriorityResult[i0] & ~|orPriorityResult[i0-1:0];
	  end
    //--------------------------------------
    //(4) Request mask
    //--------------------------------------
    for (i0 = 0; i0 < REQ_NUM; i0=i0+1) begin: ReqMask
	    for (i1 = 0; i1 < REQ_NUM; i1=i1+1) begin: BitMask
	      assign newGrant[i1+i0*REQ_NUM] = compResult[i1+i0*REQ_NUM] & reqEn[i1];
	    end
	  end
	  //--------------------------------------
    //(5) Grant set
    //--------------------------------------
	  for (i0 = 0; i0 < REQ_NUM; i0=i0+1) begin: uSetGrant
	    assign setGrant[i0] = |newGrant[REQ_NUM*(i0+1)-1:i0*REQ_NUM];
	  end
    //--------------------------------------
    //(6) Same priority filter
    //--------------------------------------
    assign setPriorityGrant[0] = setGrant[0];
    for (i0 = 1; i0 < REQ_NUM; i0=i0+1) begin: uSetPriGrant
	    assign setPriorityGrant[i0] = setGrant[i0] & ~|setGrant[i0-1:0];
	  end
	  //
  endgenerate
  //--------------------------------------
  //(7) Grant
  //--------------------------------------
  generate
    genvar j;
    //
	  for (j = 0; j < REQ_NUM; j=j+1) begin: uGrant
      always @ (posedge clk, negedge rst_n) begin
        if (~rst_n)
	        grant[j] <= 1'b0;
	      else if (noGrant)
	        grant[j] <= setPriorityGrant[j];
        else
          grant[j] <= grant[j] & req[j];
      end
	  end //for loop
  endgenerate
  assign noGrant = ~|grant[REQ_NUM-1:0];
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
      for(i = 0; 2**i < value; i=i+1) 
        clog2 = i + 1; 
      end 
  endfunction 
endmodule //ArbDynamicPriority