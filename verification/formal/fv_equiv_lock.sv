// Equivalence of the fixed ArbFixedPriorityLocked and the pre-fix version on every trace on which
// the OLD design never grants two sources at once (the bug that was fixed).
`ifndef N
 `define N 4
`endif
module fv_equiv_lock (input clk, input [`N-1:0] req, input [`N-1:0] lockIn);
  localparam N = `N;
  reg init = 1'b1;  always @(posedge clk) init <= 1'b0;
  wire rst_n = ~init;
  reg okq = 1'b0;   always @(posedge clk) okq <= ~init;
  wire ok = okq & ~init;
  wire [N-1:0] g_new, g_old; wire s_new, s_old;
  `NEWMOD #(.REQ_NUM(N)) u_new (.clk(clk), .rst_n(rst_n), .req(req), .lockIn(lockIn), .lockSta(s_new), .grant(g_new));
  `OLDMOD #(.REQ_NUM(N)) u_old (.clk(clk), .rst_n(rst_n), .req(req), .lockIn(lockIn), .lockSta(s_old), .grant(g_old));
  always @* if (ok) assume ((g_old & (g_old - 1'b1)) == 0);
  always @* if (ok) assert (g_new == g_old && s_new == s_old);
endmodule
