module fv_bal #(parameter N=4, parameter W=2) (input clk, input [N-1:0] req);
  wire [N-1:0] grant;
  `include "pre.svh"
  ArbBalanceRR #(.REQ_NUM(N)) dut (.clk(clk), .rst_n(rst_n), .req(req), .grant(grant));
  // reference model: least-recently-granted list (level 0 = highest priority)
  reg [N*W-1:0] lvl = 0;
  reg [N-1:0] winner, pred; reg found; reg [W-1:0] best; integer i;
  always @* begin
    winner = 0; found = 1'b0; best = 0;
    for (i = 0; i < N; i = i + 1)
      if (req[i] && (!found || lvl[i*W +: W] < best)) begin winner = (1 << i); found = 1'b1; best = lvl[i*W +: W]; end
    pred = (grant == 0) ? winner : (grant & req);
  end
  always @(posedge clk) begin
    if (init) for (i = 0; i < N; i = i + 1) lvl[i*W +: W] <= i;
    else if (grant == 0 && req != 0)
      for (i = 0; i < N; i = i + 1)
        if (winner[i]) lvl[i*W +: W] <= N - 1;
        else if (lvl[i*W +: W] > best) lvl[i*W +: W] <= lvl[i*W +: W] - 1'b1;
  end
  reg [N-1:0] pred_q = 0; always @(posedge clk) pred_q <= pred;
  always @* if (ok) begin
`ifdef P_ONEHOT  assert ((grant & (grant - 1'b1)) == 0); `endif
`ifdef P_SUBSET  assert ((grant & ~req_q) == 0); `endif
`ifdef P_HOLD    assert (((grant_q & req_q) & ~grant) == 0); `endif
`ifdef P_WC      if (grant_q == 0 && req_q != 0) assert (grant != 0); `endif
`ifdef P_EXACT   assert (grant == pred_q); `endif
`ifdef P_BUBBLE  if (grant_q != 0 && (grant_q & req_q) == 0) assert (grant == 0); `endif
  end
endmodule
