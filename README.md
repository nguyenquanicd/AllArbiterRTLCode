# AllArbiterRTLCode

Synthesizable Verilog RTL of seven arbitration algorithms (originally synthesized with Quartus II).
All arbiters share the same behavior model, described below, so they can be swapped easily.

Detail description (Vietnamese): http://nguyenquanicd.blogspot.com/search/label/Arbiter?&max-results=5

## RTL list

| # | File / module | Algorithm | Preemptive | Starvation-free |
|---|---|---|---|---|
| 1 | `ArbFixedPriorityAbs.v` | Absolute fixed priority, `req[0]` highest | Yes (a higher request revokes the grant at once) | No |
| 2 | `ArbFixedPriorityNAbs.v` | Non-absolute fixed priority | No | No |
| 3 | `ArbFixedPriorityLocked.v` | Non-absolute fixed priority + `lockIn` | No | No (a held lock blocks everybody) |
| 4 | `ArbDynamicPriority.v` | Priority level per request (`priorityLevel`), ties -> lower index | No | No (ties) |
| 5 | `ArbSimpleRR.v` | Round robin with a slot counter (TDM style) | No | Yes |
| 6 | `ArbPriorityRR.v` | Round robin with a rotating priority pointer (also contains helper module `ArbPriorityLogic`) | No | Yes |
| 7 | `ArbBalanceRR.v` | Balance (least-recently-granted first) round robin | No | Yes |

## Common interface and behavior

* Port list: `clk`, `rst_n` (asynchronous, active low), `req[REQ_NUM-1:0]`, `grant[REQ_NUM-1:0]`.
  Extra ports: `lockIn`, `lockSta` (Locked) and `priorityLevel` (Dynamic).
* Parameter `REQ_NUM` (default 4). Any value >= 1 is legal. `COUNTER_W`, `PRI_WIDTH`, `PRI_TOTALW` are derived `localparam`s.
* `grant` is a registered one-hot (or zero) vector. It is never multi-hot.
* **Latency:** `grant` follows `req` one clock later, and it also falls one clock after `req` falls
  (a "trailing grant"). The receiver must qualify `grant` with its own state.
* **Hand-off bubble:** except for `ArbFixedPriorityAbs`, `grant` is zero for one clock between two owners,
  so the bus utilization of bursts of L cycles is L/(L+1) (measured 83% for L=4).
* Non-preemptive arbiters keep the grant while the owner keeps `req` asserted.

### Per-module notes

* **Abs:** `grant[i] = req[i] & ~|req[i-1:0]` registered. Low priority sources are starved by design.
* **NAbs:** arbitrates only when `grant` is zero.
* **Locked:** a source that is granted with `lockIn[i]=1` becomes the lock owner. While the owner keeps `lockIn`
  asserted, no other source is granted, even when the owner is idle. `lockSta` reports a lock.
  **Hazard:** a `lockIn` stuck at 1 blocks all other sources (there is no time-out).
* **Dynamic:** `priorityLevel` has `PRI_WIDTH = ceil(log2(REQ_NUM))` bits per request, level 0 = highest.
  It is sampled only when a new arbitration happens. Equal levels are resolved by index, so equal levels can starve the higher indexes.
  A level outside `0..REQ_NUM-1` (possible when `REQ_NUM` is not a power of 2) is treated as the lowest level.
* **SimpleRR:** a free running slot counter selects which source may be granted; a request waits for its slot.
* **PriorityRR:** the pointer advances when the owner releases or when nobody requests. Wait is bounded (<= 16 clocks for 4 sources if every owner holds <= 2 clocks).
* **BalanceRR:** every source has a priority level; the granted source drops to the lowest level and the others move up. Wait is bounded (<= 14 clocks for 4 sources, same assumption).

## Change log (2026.10.10) - bugs found by formal verification and simulation

| File | Problem | Fix |
|---|---|---|
| `ArbFixedPriorityLocked.v` | **Two grants at once:** a lock owner that released `lockIn` and requested together with a higher priority source got `grant` for both. | Arbitration is disabled while a lock owner is requesting (`arbEn`). |
| `ArbPriorityRR.v` | **Grant revoked** while `req` was still asserted when a newcomer had a better rotated priority (`nextGrant & grant`); the pointer then never advanced, so a source could starve. | The grant is held with `grant & req`. |
| `ArbDynamicPriority.v` | A request whose level was out of range (non power-of-2 `REQ_NUM`) was ignored forever. | The level is clamped to the lowest level. |
| All RR / Dynamic modules | `REQ_NUM=1` created a zero-width vector; derived parameters could be overridden; lint warnings; wrong header comment (`ArbBalanceRR`); global module name `priorityLogic`. | `clog2` has a minimum of 1, derived values are `localparam`, lint clean, comments fixed, helper renamed `ArbPriorityLogic`. |

Not changed on purpose (documented behavior): the hand-off bubble, the trailing grant, fixed-priority starvation and the lock hazard.

## Repository layout

| Path | Content |
|---|---|
| `Arb*.v` | The seven arbiters (RTL) |
| `verification/formal/` | SymbiYosys harnesses (`fv_*.sv`, `pre.svh`), `run_formal.ps1` (66 cases), `run_equiv.ps1` (old-versus-new equivalence) |
| `verification/sim/` | `tb_regress.sv` (regression of the fixes), `tb_sat.sv` (saturation / fairness / utilization), `run_sim.ps1` |

Generated folders (`work`, `work_equiv`) are ignored by git.

## Verification

Tools: OSS CAD Suite (yosys, SymbiYosys with the `abc pdr` engine, iverilog) and, for lint, Verilator.
The scripts are PowerShell scripts; they use `sby`/`iverilog` from `PATH`, otherwise they load
`C:\Tools\oss-cad-suite\environment.ps1` (change it with `-OssCad`). Every script exits with 0 when all checks pass.

```powershell
cd verification\formal
.\run_formal.ps1            # 66 formal cases, about 30 s with 6 jobs (-Jobs 6)
.\run_equiv.ps1             # current RTL versus the pre-fix commit 1caa847 (git history is required)
cd ..\sim
.\run_sim.ps1               # directed + random regression, then saturation of every arbiter
```

Every script accepts `-RtlDir <dir>` to check another copy of the RTL (for example an older revision).

### What is checked

* **`run_formal.ps1`** proves (unbounded, `abc pdr`) for `REQ_NUM` = 4, 3, 5 (Balance also 6):
  one-hot grant, grant implies a request in the previous clock, grant hold, work conserving behavior,
  the hand-off bubble, exact arbitration (Abs, NAbs, Dynamic against a priority reference, Balance against a
  least-recently-granted reference model, SimpleRR slot ownership) and the maximum wait of the lowest priority source
  (4 sources, every other source keeps the grant at most 2 clocks):

  | Arbiter | Proved wait bound | One cycle less |
  |---|---|---|
  | SimpleRR | <= 14 clocks | 12 clocks fails |
  | BalanceRR | <= 14 clocks | 12 clocks fails |
  | PriorityRR | <= 16 clocks | 14 clocks fails |
  | Abs, NAbs | no bound (starvation by design) | - |

* **`run_equiv.ps1`** proves that the fixed SimpleRR, BalanceRR, PriorityRR, Locked and Dynamic produce the same `grant`
  as revision `1caa847` on every input sequence, apart from the behaviors that were deliberately fixed
  (those traces are excluded by an assumption: no grant revoked while `req` is high in the old PriorityRR,
  never two grants in the old Locked, legal priority levels in Dynamic). 14 cases, all equivalent.
  Abs and NAbs are unchanged.
* **`run_sim.ps1`:** `tb_regress.sv` replays the formal counterexamples, runs the `REQ_NUM=1` smoke test and
  20000 random cycles (monitors: one-hot, grant hold, work conserving); `tb_sat.sv` measures fairness and utilization with
  four masters requesting continuously (bursts of 4 cycles + 1 idle, and bursts of 1 cycle).
  Result for the fair arbiters: every master is served, no grant is revoked.

### Do the checks detect the bugs?

Run against the pre-fix RTL (commit `1caa847`), the same scripts fail exactly where expected:

| Check | Pre-fix RTL |
|---|---|
| `run_formal.ps1 -Only '^(locked\|prr_n4\|dyn_n3\|wait_ArbPriorityRR)'` | 5 of 11 cases fail: Locked N=4 and N=2 (two grants), PriorityRR grant hold, PriorityRR wait bound, Dynamic N=3 work conserving |
| `run_sim.ps1 -SkipReqNum1` | `TB_RESULT FAIL`: Locked multi-hot, PriorityRR grant lost, Dynamic level 3 never granted |
| `run_sim.ps1` | does not compile: `Concatenation repeat may not be zero` for `REQ_NUM=1` |
| `run_equiv.ps1` without the exclusion assumptions | not equivalent (checked once for PriorityRR, Locked and Dynamic N=3) |

### Lint

Verilator `-Wall` is clean for `REQ_NUM` = 1, 2, 3, 4, 5, 8 (the style note DECLFILENAME is disabled because
`ArbPriorityRR.v` also contains the helper module `ArbPriorityLogic`).

## Resource scale (yosys generic gates, REQ_NUM = 4 / 8 / 16)

Abs 9/21/48, NAbs 18/38/78, SimpleRR 27/59/122, Locked 49/101/205, PriorityRR 61/165/511, Dynamic 85/343/1274, Balance 157/567/1971.
Dynamic and Balance grow roughly with `REQ_NUM^2`.
