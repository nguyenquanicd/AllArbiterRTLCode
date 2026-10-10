`timescale 1ns/1ps
//------------------------------------------------------------------------------
// Regression of the fixes made on 2026.10.10 (iverilog -g2012 or any SV simulator)
//   A. ArbFixedPriorityLocked : never two grants at once (directed replay of the formal
//                               counterexample + random stress)
//   B. ArbPriorityRR          : a granted source keeps the grant while req is asserted
//                               (directed one-cycle pulse of a better priority source + random)
//   C. ArbDynamicPriority     : REQ_NUM=3, a priority level of 3 (out of range) is still served
//   D. REQ_NUM=1 smoke test of every arbiter (no zero-width vector, grant follows req)
// Prints "TB_RESULT PASS" or "TB_RESULT FAIL ..." at the end.
//------------------------------------------------------------------------------
module tb_regress;
  reg clk = 0, rst_n = 0;
  always #5 clk = ~clk;
  integer errors = 0;
  reg live = 0;                       // monitors are enabled after reset

  //---------------- A. Locked, 4 sources ----------------
  reg  [3:0] lk_req = 0, lk_lock = 0;
  wire [3:0] lk_g;
  wire       lk_sta;
  ArbFixedPriorityLocked #(.REQ_NUM(4)) u_lock (.clk(clk), .rst_n(rst_n), .req(lk_req), .lockIn(lk_lock), .lockSta(lk_sta), .grant(lk_g));
  integer lk_multi = 0;
  always @(posedge clk) if (live && ((lk_g & (lk_g - 1'b1)) != 0)) lk_multi = lk_multi + 1;

  //---------------- B. PriorityRR, 4 sources ----------------
  reg  [3:0] pr_req = 0;
  wire [3:0] pr_g;
  ArbPriorityRR #(.REQ_NUM(4)) u_prr (.clk(clk), .rst_n(rst_n), .req(pr_req), .grant(pr_g));
  reg [3:0] pr_rq = 0, pr_gq = 0;
  integer pr_hold_err = 0, pr_multi = 0;
  always @(posedge clk) begin
    pr_rq <= pr_req; pr_gq <= pr_g;
    if (live) begin
      if (((pr_gq & pr_rq) & ~pr_g) != 0) pr_hold_err = pr_hold_err + 1;    // grant lost while req stayed high
      if ((pr_g & (pr_g - 1'b1)) != 0)    pr_multi = pr_multi + 1;
    end
  end

  //---------------- C. Dynamic priority, 3 sources ----------------
  reg  [2:0] dy_req = 0;
  reg  [5:0] dy_lvl = 0;               // 2 bits per source, value 3 is out of range for 3 sources
  wire [2:0] dy_g;
  ArbDynamicPriority #(.REQ_NUM(3)) u_dyn3 (.clk(clk), .rst_n(rst_n), .req(dy_req), .priorityLevel(dy_lvl), .grant(dy_g));
  reg [2:0] dy_rq = 0, dy_gq = 0;
  integer dy_hold_err = 0, dy_multi = 0, dy_wc_err = 0;
  always @(posedge clk) begin
    dy_rq <= dy_req; dy_gq <= dy_g;
    if (live) begin
      if (((dy_gq & dy_rq) & ~dy_g) != 0)          dy_hold_err = dy_hold_err + 1;
      if ((dy_g & (dy_g - 1'b1)) != 0)             dy_multi = dy_multi + 1;
      if (dy_gq == 0 && dy_rq != 0 && dy_g == 0)   dy_wc_err = dy_wc_err + 1;  // work conserving
    end
  end

`ifndef NO_ONE
  //---------------- D. REQ_NUM = 1 ----------------
  reg  one_req = 0;
  reg  one_lvl = 0;
  wire g1_abs, g1_nabs, g1_srr, g1_prr, g1_bal, g1_dyn, g1_lock, s1_lock;
  ArbFixedPriorityAbs    #(.REQ_NUM(1)) u1_abs  (.clk(clk), .rst_n(rst_n), .req(one_req), .grant(g1_abs));
  ArbFixedPriorityNAbs   #(.REQ_NUM(1)) u1_nabs (.clk(clk), .rst_n(rst_n), .req(one_req), .grant(g1_nabs));
  ArbSimpleRR            #(.REQ_NUM(1)) u1_srr  (.clk(clk), .rst_n(rst_n), .req(one_req), .grant(g1_srr));
  ArbPriorityRR          #(.REQ_NUM(1)) u1_prr  (.clk(clk), .rst_n(rst_n), .req(one_req), .grant(g1_prr));
  ArbBalanceRR           #(.REQ_NUM(1)) u1_bal  (.clk(clk), .rst_n(rst_n), .req(one_req), .grant(g1_bal));
  ArbDynamicPriority     #(.REQ_NUM(1)) u1_dyn  (.clk(clk), .rst_n(rst_n), .req(one_req), .priorityLevel(one_lvl), .grant(g1_dyn));
  ArbFixedPriorityLocked #(.REQ_NUM(1)) u1_lock (.clk(clk), .rst_n(rst_n), .req(one_req), .lockIn(1'b0), .lockSta(s1_lock), .grant(g1_lock));
  wire [6:0] g1_all = {g1_abs, g1_nabs, g1_srr, g1_prr, g1_bal, g1_dyn, g1_lock};
  reg  [6:0] seen_hi, seen_lo;

`endif

  task step; begin @(posedge clk); #1; end endtask
  task check(input cond, input [8*80-1:0] what);
    begin
      if (!cond) begin errors = errors + 1; $display("FAIL: %0s (t=%0t)", what, $time); end
    end
  endtask

  integer k;
  initial begin
    //---------------- reset ----------------
    rst_n = 0; step; step;
    // B first: the pointer of ArbPriorityRR is still 0 only if the requests start right after reset
    rst_n = 1; live = 1;
    $display("--- B. ArbPriorityRR: source 2 holds the grant, source 0 pulses req for one cycle ---");
    pr_req = 4'b0100; step; step; step;                 // source 2 granted
    check(pr_g[2] === 1'b1, "source 2 is granted");
    pr_req = 4'b0101; step;                             // source 0 (better rotated priority) pulses
    pr_req = 4'b0100; step; step; step;
    check(pr_hold_err == 0, "PriorityRR keeps the grant while req is asserted");
    check(pr_g[2] === 1'b1, "source 2 still owns the grant after the pulse");
    pr_req = 4'b0000; step; step;

    //---------------- A. Locked: replay of the formal counterexample ----------------
    $display("--- A. ArbFixedPriorityLocked: lock owner releases lockIn together with a higher priority request ---");
    lk_req = 4'b1100; lk_lock = 4'b1111; step;          // source 2 wins and locks
    lk_req = 4'b1001; lk_lock = 4'b1101; step;          // owner idles but keeps the lock, lockIn[2] released
    lk_req = 4'b0101; lk_lock = 4'b1001; step;          // owner requests again together with higher priority source 0
    lk_req = 4'b0000; lk_lock = 4'b0000; step; step; step;
    check(lk_multi == 0, "Locked: grant is never multi-hot (directed)");

    //---------------- C. Dynamic: level 3 is out of range for 3 sources ----------------
    $display("--- C. ArbDynamicPriority REQ_NUM=3: a request with level 3 is still granted ---");
    dy_lvl = {2'd3, 2'd0, 2'd0}; dy_req = 3'b100;
    for (k = 0; k < 5; k = k + 1) step;
    check(dy_g[2] === 1'b1, "request with an out-of-range level is granted");
    dy_req = 3'b000; step; step;

`ifndef NO_ONE
    //---------------- D. REQ_NUM = 1 smoke ----------------
    $display("--- D. REQ_NUM=1: grant follows req ---");
    seen_hi = 0; seen_lo = 7'h7f;
    one_req = 1;
    for (k = 0; k < 8; k = k + 1) begin step; seen_hi = seen_hi | g1_all; end
    check(seen_hi === 7'h7f, "REQ_NUM=1: every arbiter grants the single source");
    one_req = 0;
    for (k = 0; k < 4; k = k + 1) step;
    check(g1_all === 7'h00, "REQ_NUM=1: grant is released after req");

`endif
    //---------------- random stress ----------------
    $display("--- random stress, 20000 cycles ---");
    for (k = 0; k < 20000; k = k + 1) begin
      lk_req = $urandom; lk_lock = $urandom & $urandom;
      pr_req = pr_req ^ ($urandom & $urandom);          // slow toggling -> long requests
      dy_req = dy_req ^ ($urandom & $urandom);
      dy_lvl = $urandom;                                // includes the out-of-range value 3
      step;
    end
    check(lk_multi == 0,      "Locked: grant never multi-hot (random)");
    check(pr_hold_err == 0,   "PriorityRR: grant hold (random)");
    check(pr_multi == 0,      "PriorityRR: one-hot (random)");
    check(dy_hold_err == 0,   "Dynamic N=3: grant hold (random)");
    check(dy_multi == 0,      "Dynamic N=3: one-hot (random)");
    check(dy_wc_err == 0,     "Dynamic N=3: work conserving (random, incl. out-of-range levels)");

    if (errors == 0) $display("TB_RESULT PASS");
    else             $display("TB_RESULT FAIL errors=%0d lk_multi=%0d pr_hold=%0d dy_wc=%0d", errors, lk_multi, pr_hold_err, dy_wc_err);
    $finish;
  end
endmodule
