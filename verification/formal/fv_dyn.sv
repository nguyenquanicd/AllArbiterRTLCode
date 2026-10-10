module fv_dyn #(parameter N=4, parameter W=2) (input clk, input [N-1:0] req, input [N*W-1:0] prio);
  wire [N-1:0] grant;
  `include "pre.svh"
  reg [N*W-1:0] prio_q = 0; always @(posedge clk) prio_q <= prio;
  ArbDynamicPriority #(.REQ_NUM(N)) dut (.clk(clk), .rst_n(rst_n), .req(req), .priorityLevel(prio), .grant(grant));
  // reference arbitration: lowest level number wins, ties -> lowest index
  reg [N-1:0] pred; reg found; reg [W-1:0] best; integer i;
  always @* begin
    pred = 0; found = 1'b0; best = 0;
    for (i = 0; i < N; i = i + 1)
      if (req_q[i] && (!found || prio_q[i*W +: W] < best)) begin
        pred = (1 << i); found = 1'b1; best = prio_q[i*W +: W];
      end
  end
  always @* if (ok) begin
`ifdef P_ONEHOT  assert ((grant & (grant - 1'b1)) == 0); `endif
`ifdef P_SUBSET  assert ((grant & ~req_q) == 0); `endif
`ifdef P_HOLD    assert (((grant_q & req_q) & ~grant) == 0); `endif
`ifdef P_WC      if (grant_q == 0 && req_q != 0) assert (grant != 0); `endif
`ifdef P_EXACT   if (grant_q == 0 && req_q != 0) assert (grant == pred); `endif
`ifdef P_BUBBLE  if (grant_q != 0 && (grant_q & req_q) == 0) assert (grant == 0); `endif
  end
endmodule
