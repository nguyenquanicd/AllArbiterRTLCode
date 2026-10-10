module fv_srr #(parameter N=4) (input clk, input [N-1:0] req);
  wire [N-1:0] grant;
  `include "pre.svh"
  ArbSimpleRR #(.REQ_NUM(N)) dut (.clk(clk), .rst_n(rst_n), .req(req), .grant(grant));
  // reference slot counter: advances every cycle in which no grant is active
  reg [7:0] cnt = 0;
  always @(posedge clk) if (init) cnt <= 0; else if (grant == 0) cnt <= (cnt == N-1) ? 0 : cnt + 1;
  reg [7:0] cnt_q = 0; always @(posedge clk) cnt_q <= cnt;
  always @* if (ok) begin
    assert ((grant & (grant - 1'b1)) == 0);
    assert ((grant & ~req_q) == 0);
    assert (((grant_q & req_q) & ~grant) == 0);                    // hold
    if (grant_q != 0 && (grant_q & req_q) == 0) assert (grant == 0); // bubble
    // a NEW grant (from idle) may only go to the owner of the current time slot
    if (grant_q == 0 && grant != 0) assert (grant == (1 << cnt_q[3:0]));
    if (grant_q == 0 && (req_q & (1 << cnt_q[3:0])) != 0) assert (grant == (1 << cnt_q[3:0]));
  end
endmodule
