// Equivalence of the fixed ArbDynamicPriority and the pre-fix version for legal priority levels.
// ASSUME_LEGAL : every level is < REQ_NUM (always true when REQ_NUM is a power of 2).
`ifndef N
 `define N 4
`endif
`ifndef W
 `define W 2
`endif
module fv_equiv_dyn (input clk, input [`N-1:0] req, input [`N*`W-1:0] prio);
  localparam N = `N, W = `W;
  reg init = 1'b1;  always @(posedge clk) init <= 1'b0;
  wire rst_n = ~init;
  reg okq = 1'b0;   always @(posedge clk) okq <= ~init;
  wire ok = okq & ~init;
  wire [N-1:0] g_new, g_old;
  `NEWMOD #(.REQ_NUM(N)) u_new (.clk(clk), .rst_n(rst_n), .req(req), .priorityLevel(prio), .grant(g_new));
  `OLDMOD #(.REQ_NUM(N)) u_old (.clk(clk), .rst_n(rst_n), .req(req), .priorityLevel(prio), .grant(g_old));
  integer i;
`ifdef ASSUME_LEGAL
  always @* for (i = 0; i < N; i = i + 1) assume (prio[i*W +: W] < N);
`endif
  always @* if (ok) assert (g_new == g_old);
endmodule
