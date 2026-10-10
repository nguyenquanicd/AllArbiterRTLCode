module fv_locked #(parameter N=4) (input clk, input [N-1:0] req, input [N-1:0] lockIn);
  wire [N-1:0] grant; wire lockSta;
  `include "pre.svh"
  reg [N-1:0] lockIn_q = 0; always @(posedge clk) lockIn_q <= lockIn;
  ArbFixedPriorityLocked #(.REQ_NUM(N)) dut (.clk(clk), .rst_n(rst_n), .req(req), .lockIn(lockIn), .lockSta(lockSta), .grant(grant));
  always @* if (ok) begin
    assert ((grant & (grant - 1'b1)) == 0);       // L1 one-hot or zero (was violated before the 2026.10.10 fix)
  end
  always @* if (ok) begin
    assert ((grant & ~req_q) == 0);                // L2 grant implies request in previous cycle
    if (lockSta) assert (lockIn_q != 0);           // L3 lock status implies a lockIn in the previous cycle
  end
endmodule
