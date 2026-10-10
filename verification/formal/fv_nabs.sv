module fv_nabs #(parameter N=4) (input clk, input [N-1:0] req);
  wire [N-1:0] grant;
  `include "pre.svh"
  ArbFixedPriorityNAbs #(.REQ_NUM(N)) dut (.clk(clk), .rst_n(rst_n), .req(req), .grant(grant));
  always @* if (ok) begin
    assert ((grant & (grant - 1'b1)) == 0);                 // P1 one-hot or zero
    assert ((grant & ~req_q) == 0);                          // P2 grant implies request in previous cycle
    assert (((grant_q & req_q) & ~grant) == 0);              // P3 hold: granted+requesting stays granted
    if (grant_q == 0 && req_q != 0) assert (grant == low_req_q);   // P4 exact arbitration
    if (grant_q != 0 && (grant_q & req_q) == 0) assert (grant == 0); // P5 bubble: no hand-off in same cycle
  end
endmodule
