// Equivalence of the fixed arbiter (module `NEWMOD) and the pre-fix version (module `OLDMOD),
// for the arbiters with the standard port list (clk, rst_n, req, grant).
//   ASSUME_NO_REVOKE : only traces on which the OLD arbiter never revokes a grant while req is
//                      still asserted (the PriorityRR bug) are compared.
`ifndef N
 `define N 4
`endif
module fv_equiv_std (input clk, input [`N-1:0] req);
  localparam N = `N;
  reg init = 1'b1;  always @(posedge clk) init <= 1'b0;
  wire rst_n = ~init;
  reg okq = 1'b0;   always @(posedge clk) okq <= ~init;
  wire ok = okq & ~init;
  wire [N-1:0] g_new, g_old;
  `NEWMOD #(.REQ_NUM(N)) u_new (.clk(clk), .rst_n(rst_n), .req(req), .grant(g_new));
  `OLDMOD #(.REQ_NUM(N)) u_old (.clk(clk), .rst_n(rst_n), .req(req), .grant(g_old));
  reg [N-1:0] req_q = 0, go_q = 0;
  always @(posedge clk) begin req_q <= req; go_q <= g_old; end
`ifdef ASSUME_NO_REVOKE
  always @* if (ok) assume (((go_q & req_q) & ~g_old) == 0);
`endif
  always @* if (ok) assert (g_new == g_old);
endmodule
