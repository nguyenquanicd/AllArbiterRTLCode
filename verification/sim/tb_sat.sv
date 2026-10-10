`timescale 1ns/1ps
// Saturation test: N masters request continuously (burst of L granted cycles, then G idle cycles).
// Measures grants/master, granted cycles/master, wait latency, bus utilisation and revoked grants.
`ifndef L
 `define L 4
`endif
`ifndef G
 `define G 1
`endif
`ifndef CYCLES
 `define CYCLES 20000
`endif
module tb_sat;
  localparam N = 4;
  reg clk = 0, rst_n = 0;
  reg  [N-1:0] req = 0;
  wire [N-1:0] grant;
  always #5 clk = ~clk;
`ifdef DYN
  reg [2*N-1:0] prio = 8'b00_00_00_00;       // all masters at the same level -> tie broken by index
  `DUTMOD #(.REQ_NUM(N)) dut (.clk(clk), .rst_n(rst_n), .req(req), .priorityLevel(prio), .grant(grant));
`else
  `DUTMOD #(.REQ_NUM(N)) dut (.clk(clk), .rst_n(rst_n), .req(req), .grant(grant));
`endif
  localparam IDLE = 0, REQ = 1, HOLD = 2;
  integer st [0:N-1], gapc [0:N-1], hc [0:N-1];
  integer grants [0:N-1], gcyc [0:N-1], lost [0:N-1], wsum [0:N-1], wmax [0:N-1], wst [0:N-1];
  integer cyc, busy, i, multihot, nogrant_with_req, bubbles;
  reg [N-1:0] grant_d;
  initial begin
    for (i = 0; i < N; i = i + 1) begin st[i] = IDLE; gapc[i] = i; hc[i] = 0; grants[i] = 0; gcyc[i] = 0; lost[i] = 0; wsum[i] = 0; wmax[i] = 0; wst[i] = 0; end
    cyc = 0; busy = 0; multihot = 0; nogrant_with_req = 0; bubbles = 0; grant_d = 0;
    repeat (3) @(posedge clk); rst_n = 1;
    repeat (`CYCLES) @(posedge clk);
    $display("RESULT L=%0d G=%0d cycles=%0d util=%0d%% multihot=%0d bubbles=%0d", `L, `G, `CYCLES, (100*busy)/`CYCLES, multihot, bubbles);
    for (i = 0; i < N; i = i + 1)
      $display("   m%0d: grants=%0d grantedCycles=%0d revoked=%0d avgWait=%0d maxWait=%0d", i, grants[i], gcyc[i], lost[i], (grants[i] ? wsum[i]/grants[i] : -1), wmax[i]);
    $finish;
  end
  always @(posedge clk) if (rst_n) begin
    cyc = cyc + 1;
    if (|grant) busy = busy + 1;
    if ((grant & (grant - 1'b1)) != 0) multihot = multihot + 1;
    // a "bubble" = a cycle with no grant while some master is requesting and the previous cycle had a grant
    if (grant == 0 && grant_d != 0 && req != 0) bubbles = bubbles + 1;
    grant_d = grant;
    for (i = 0; i < N; i = i + 1) begin
      if (grant[i]) gcyc[i] = gcyc[i] + 1;
      case (st[i])
        IDLE: if (gapc[i] <= 0) begin req[i] <= 1'b1; st[i] = REQ; wst[i] = cyc; end else gapc[i] = gapc[i] - 1;
        REQ:  if (grant[i]) begin
                grants[i] = grants[i] + 1; wsum[i] = wsum[i] + (cyc - wst[i]); if (cyc - wst[i] > wmax[i]) wmax[i] = cyc - wst[i];
                if (`L <= 1) begin req[i] <= 1'b0; st[i] = IDLE; gapc[i] = `G; end
                else begin hc[i] = `L - 1; st[i] = HOLD; end
              end
        HOLD: if (!grant[i]) begin lost[i] = lost[i] + 1; st[i] = REQ; wst[i] = cyc; end   // grant revoked while req is still high
              else if (hc[i] <= 1) begin req[i] <= 1'b0; st[i] = IDLE; gapc[i] = `G; end
              else hc[i] = hc[i] - 1;
      endcase
    end
  end
endmodule
