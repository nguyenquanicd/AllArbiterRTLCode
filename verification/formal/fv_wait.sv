`ifndef N
 `define N 4
`endif
module fv_wait (input clk, input [`N-1:0] req);
  localparam N = `N;
  wire [N-1:0] grant;
  `include "pre.svh"
  `DUT #(.REQ_NUM(N)) dut (.clk(clk), .rst_n(rst_n), .req(req), .grant(grant));
  // Environment: nobody keeps (req & grant) for more than H consecutive cycles (except the target K)
  reg [N*8-1:0] hc = 0; integer i;
  always @(posedge clk) for (i = 0; i < N; i = i + 1) hc[i*8 +: 8] <= (req[i] & grant[i]) ? hc[i*8 +: 8] + 1'b1 : 8'd0;
  always @* for (i = 0; i < N; i = i + 1)
    if (i != `K) assume (!(req[i] & grant[i] & (hc[i*8 +: 8] >= `H)));
  // Target K keeps its request asserted: how many consecutive cycles can it wait without grant?
  reg [7:0] wc = 0;
  always @(posedge clk) wc <= (req[`K] && !grant[`K] && !init) ? wc + 1'b1 : 8'd0;
  always @* if (ok) assert (!(req[`K] && !grant[`K]) || wc < `B);
endmodule
