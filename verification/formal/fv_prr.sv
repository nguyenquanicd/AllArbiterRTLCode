module fv_prr #(parameter N=4) (input clk, input [N-1:0] req);
  wire [N-1:0] grant;
  `include "pre.svh"
  ArbPriorityRR #(.REQ_NUM(N)) dut (.clk(clk), .rst_n(rst_n), .req(req), .grant(grant));
  always @* if (ok) begin
`ifdef P_ONEHOT  assert ((grant & (grant - 1'b1)) == 0); `endif
`ifdef P_SUBSET  assert ((grant & ~req_q) == 0); `endif
`ifdef P_HOLD    assert (((grant_q & req_q) & ~grant) == 0); `endif
`ifdef P_WC      if (grant_q == 0 && req_q != 0) assert (grant != 0); `endif
`ifdef P_BUBBLE  if (grant_q != 0 && (grant_q & req_q) == 0) assert (grant == 0); `endif
  end
endmodule
