//-------------------------------------------
//Author  : Nguyen Hung Quan
//Website : https://nguyenquanicd.blogspot.com/
//Date    : 2019.Aug.15
//Function: Priority Round Robin (RR) Arbiter
//  - Use a counter to share access right
//  - The priority level of request source is changed
//Coding style notes for VERILOG:
//  - Do NOT use "++" to increase a interation such as i++
//    => Use i=i+1
//  - Do NOT declare a interation inside "for" statement such as "for (integer i;..."
//    => Declare "integer i" outside for loop
//  - In a function, a constant maybe is assigned from input by declaring "input integer ..."
//    => example: "input integer index;" -> Do NOT declare "input index;"
//-------------------------------------------
module ArbPriorityRR (
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
  wire incCounter;
  wire [REQ_NUM-1:0] prioritySel;
  wire [REQ_NUM*REQ_NUM-1:0] reqOut;
  wire [REQ_NUM*REQ_NUM-1:0] reqOutVector;
  wire noGrant;
  wire [REQ_NUM-1:0] nextGrant;
  //
  assign noGrant = ~|grant[REQ_NUM-1:0];
  //Increase counter if no request or END of current request
  assign incCounter = (~|req[REQ_NUM-1:0]) | |(~req[REQ_NUM-1:0] & grant[REQ_NUM-1:0]);
  //
  always @ (posedge clk, negedge rst_n) begin
    if (~rst_n)
	    rrCounter[COUNTER_W-1:0] <= {COUNTER_W{1'b0}};
	  else if (incCounter) begin
	    if (rrCounter[COUNTER_W-1:0] == REQ_NUM-1)
	      rrCounter[COUNTER_W-1:0] <= {COUNTER_W{1'b0}};
      else
	      rrCounter[COUNTER_W-1:0] <= rrCounter[COUNTER_W-1:0] + 1'b1;
    end
  end
  //
  //Select priority logic
  //
  generate
    genvar i;
    //
	  for (i = 0; i < REQ_NUM; i=i+1) begin: uPrioritySel
      assign prioritySel[i]    = (rrCounter[COUNTER_W-1:0] == i);
	  end //for loop
  endgenerate
  //
  //Connect inputs to priority logic
  //
  //for req[0]
  priorityLogic #(.REQ_NUM(REQ_NUM)) priorityLogic0 (
       .Sel(prioritySel[0]),
       .reqIn(req[REQ_NUM-1:0]),
       .reqOut(reqOut[REQ_NUM-1:0])
       );
  generate
    genvar j;
	  for (j = 1; j < REQ_NUM; j=j+1) begin: uPResult
      //Note: Can NOT declare instance array priorityLogic[j] -> Can NOT synthesize
      //Must declare priorityLogic[j:j]
      priorityLogic #(.REQ_NUM(REQ_NUM)) priorityLogic (
       .Sel(prioritySel[j]),
       .reqIn({req[j-1:0], req[REQ_NUM-1:j]}),
       .reqOut(reqOut[REQ_NUM*(j+1)-1:j*REQ_NUM])
       );
	  end //for loop
  endgenerate
  //
  //Shift the output result
  //
  generate
    genvar x;
    assign reqOutVector[REQ_NUM-1:0] = reqOut[REQ_NUM-1:0];
	  for (x = 1; x < REQ_NUM; x=x+1) begin: reOrderBit
      //Case REQ_NUM = 4
      //x=1 [7:4]   = [6:4][7:7]
      //x=2 [11:8]  = [9:8][11:10]
      //x=3 [15:12] = [12:12][15:13]
	    assign reqOutVector[REQ_NUM*(x+1)-1:x*REQ_NUM] = {reqOut[REQ_NUM*(x+1)-1-x:x*REQ_NUM], reqOut[REQ_NUM*(x+1)-1:REQ_NUM*(x+1)-x]};
	  end
  endgenerate
  //
  //Create grant
  //
  generate
    genvar y;
    for (y = 0; y < REQ_NUM; y = y +1) begin: nextGrantGen
      assign nextGrant[y] = orOut(reqOutVector[REQ_NUM*REQ_NUM-1:0],y);
    end
  endgenerate
  //
  always @ (posedge clk, negedge rst_n) begin
    if (~rst_n)
      grant[REQ_NUM-1:0] <= {REQ_NUM{1'b0}};
    else if (noGrant)
      grant[REQ_NUM-1:0] <= nextGrant[REQ_NUM-1:0];
    else
      grant[REQ_NUM-1:0] <= nextGrant[REQ_NUM-1:0] & grant[REQ_NUM-1:0];
  end
  //
  //For synthesis
  //
  function orOut;
   input [REQ_NUM*REQ_NUM-1:0] orIn;
   input integer index;
	 integer i1;
    begin
		  orOut = 1'b0;
      for (i1 = 0; i1 < REQ_NUM; i1 = i1 + 1) begin
          orOut = orOut | orIn[index+i1*REQ_NUM];
      end
    end
  endfunction
  //
  //Not for sunthesis, Only use to calculate the parameter
  //
  function integer clog2; 
   input integer value;
	 integer ii;
    begin
      clog2 = 0; 
      for(ii = 0; 2**ii < value; ii = ii+1) begin
        clog2 = ii + 1; 
      end
    end      
  endfunction
  //
endmodule //ArbPriorityRR

module priorityLogic (Sel, reqIn, reqOut);
  parameter REQ_NUM    = 2;
  //
  input Sel;
  input [REQ_NUM-1:0] reqIn;
  output wire [REQ_NUM-1:0] reqOut;
  //
  assign reqOut[0] = Sel? reqIn[0]: 1'b0;
  generate
    genvar k;
    for (k=1; k < REQ_NUM; k = k + 1) begin: uPLogic
      assign reqOut[k] = Sel? (reqIn[k] & ~|reqIn[k-1:0]): 1'b0;
    end
  endgenerate
endmodule
