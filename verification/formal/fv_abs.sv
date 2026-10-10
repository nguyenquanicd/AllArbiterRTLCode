module fv_abs #(parameter N=4) (input clk, input [N-1:0] req);
  wire [N-1:0] grant;
  `include "pre.svh"
  ArbFixedPriorityAbs #(.REQ_NUM(N)) dut (.clk(clk), .rst_n(rst_n), .req(req), .grant(grant));
  always @* if (ok) begin
    assert ((grant & (grant - 1'b1)) == 0);                 // one-hot or zero
    assert (grant == low_req_q);                             // exact: grant = lowest set bit of previous req
  end
endmodule
