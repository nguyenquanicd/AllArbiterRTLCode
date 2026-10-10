  reg init = 1'b1;  always @(posedge clk) init <= 1'b0;
  wire rst_n = ~init;                       // reset asserted in cycle 0 only
  reg okq = 1'b0;   always @(posedge clk) okq <= ~init;
  wire ok = okq & ~init;                    // outputs are meaningful from cycle 2
  reg [N-1:0] req_q = 0, grant_q = 0;
  always @(posedge clk) begin req_q <= req; grant_q <= grant; end
  wire [N-1:0] low_req_q = req_q & (~req_q + 1'b1);   // lowest set bit of previous req
