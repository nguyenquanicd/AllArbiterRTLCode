<#
.SYNOPSIS
  Runs all formal checks of the arbiter RTL with SymbiYosys (engine "abc pdr", unbounded proofs).

.DESCRIPTION
  For every case a .sby file is generated in .\work, then run. The actual result is compared with
  the expected one (PASS, or FAIL for the documented starvation of the fixed priority arbiters).
  Exit code 0 = every case matches its expectation.

.PARAMETER RtlDir   Directory that contains the Arb*.v files (default: the repository root).
.PARAMETER Jobs     Number of parallel sby processes.
.PARAMETER Only     Regex, run only the cases whose name matches.
.PARAMETER OssCad   OSS CAD Suite directory, used when sby is not already on PATH.

.EXAMPLE
  .\run_formal.ps1
  .\run_formal.ps1 -Only '^prr'
#>
param(
  [string]$RtlDir = (Join-Path $PSScriptRoot '..\..'),
  [int]$Jobs = 4,
  [string]$Only = '',
  [string]$OssCad = 'C:\Tools\oss-cad-suite'
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command sby -ErrorAction SilentlyContinue)) {
  . (Join-Path $OssCad 'environment.ps1') *> $null
}
if (-not (Get-Command sby -ErrorAction SilentlyContinue)) { throw 'sby not found. Install the OSS CAD Suite or pass -OssCad.' }

$rtl  = (Resolve-Path $RtlDir).Path -replace '\\', '/'
$here = $PSScriptRoot -replace '\\', '/'
$work = Join-Path $PSScriptRoot 'work'
New-Item -ItemType Directory -Force $work | Out-Null

# ---------------------------------------------------------------- case table
$cases = New-Object System.Collections.Generic.List[object]
function Add-Case($name, $harness, $top, $dut, $defs = '', $chparam = '', $expect = 'PASS', $depth = 60) {
  $cases.Add([pscustomobject]@{ Name = $name; Harness = $harness; Top = $top; Dut = $dut; Defs = $defs; Chparam = $chparam; Expect = $expect; Depth = $depth })
}
# exact / structural properties, REQ_NUM = 4, 3, 5
foreach ($n in 4, 3, 5) {
  $cp = "-set N $n"
  Add-Case "abs_n$n"  fv_abs  fv_abs  ArbFixedPriorityAbs  '' $cp
  Add-Case "nabs_n$n" fv_nabs fv_nabs ArbFixedPriorityNAbs '' $cp
  Add-Case "srr_n$n"  fv_srr  fv_srr  ArbSimpleRR          '' $cp
}
Add-Case 'locked_n4' fv_locked fv_locked ArbFixedPriorityLocked '' '-set N 4'
Add-Case 'locked_n2' fv_locked fv_locked ArbFixedPriorityLocked '' '-set N 2'
foreach ($p in 'P_ONEHOT', 'P_SUBSET', 'P_HOLD', 'P_WC', 'P_EXACT', 'P_BUBBLE') {
  Add-Case "dyn_n4_$p" fv_dyn fv_dyn ArbDynamicPriority "-D$p" '-set N 4 -set W 2'
}
foreach ($p in 'P_ONEHOT', 'P_WC') {      # REQ_NUM=3: a level of 3 is out of range and must still be served
  Add-Case "dyn_n3_$p" fv_dyn fv_dyn ArbDynamicPriority "-D$p" '-set N 3 -set W 2'
}
foreach ($n in 4, 3, 5) {
  foreach ($p in 'P_ONEHOT', 'P_SUBSET', 'P_HOLD', 'P_WC', 'P_BUBBLE') {
    Add-Case "prr_n${n}_$p" fv_prr fv_prr ArbPriorityRR "-D$p" "-set N $n"
  }
}
foreach ($cfg in @(@(4, 2), @(3, 2), @(5, 3), @(6, 3))) {
  foreach ($p in 'P_ONEHOT', 'P_SUBSET', 'P_HOLD', 'P_WC', 'P_EXACT', 'P_BUBBLE') {
    Add-Case "bal_n$($cfg[0])_$p" fv_bal fv_bal ArbBalanceRR "-D$p" "-set N $($cfg[0]) -set W $($cfg[1])"
  }
}
# maximum wait of the lowest priority source (K=3, 4 sources, every other source keeps the grant <= 2 cycles)
function Add-Wait($dut, $b, $expect) {
  Add-Case "wait_${dut}_B$b" fv_wait fv_wait $dut "-DDUT=$dut -DK=3 -DH=2 -DB=$b" '' $expect 80
}
Add-Wait ArbSimpleRR   14 PASS;  Add-Wait ArbSimpleRR   12 FAIL
Add-Wait ArbBalanceRR  14 PASS;  Add-Wait ArbBalanceRR  12 FAIL
Add-Wait ArbPriorityRR 16 PASS;  Add-Wait ArbPriorityRR 14 FAIL
Add-Wait ArbFixedPriorityAbs  30 FAIL     # starvation by design (no bound)
Add-Wait ArbFixedPriorityNAbs 30 FAIL     # starvation by design (no bound)

if ($Only) { $cases = @($cases | Where-Object { $_.Name -match $Only }) }

# ---------------------------------------------------------------- sby file generation
foreach ($c in $cases) {
  $chp = if ($c.Chparam) { "chparam $($c.Chparam) $($c.Top)`n" } else { '' }
  $txt = @"
[tasks]
t

[options]
mode prove
depth $($c.Depth)

[engines]
abc pdr

[script]
read_verilog -formal -sv -I. $($c.Defs) $($c.Dut).v $($c.Harness).sv
${chp}prep -top $($c.Top)

[files]
$rtl/$($c.Dut).v
$here/$($c.Harness).sv
$here/pre.svh
"@
  Set-Content -Path (Join-Path $work "$($c.Name).sby") -Value $txt -Encoding ASCII
}

# ---------------------------------------------------------------- run (throttled)
$running = @{}
$queue = New-Object System.Collections.Queue
foreach ($c in $cases) { $queue.Enqueue($c) }
$results = @{}
function Collect($name, $proc) {
  $log = Join-Path $work "$name.log"
  $res = 'ERROR'
  if (Test-Path $log) {
    $m = Select-String -Path $log -Pattern 'DONE \((PASS|FAIL|UNKNOWN|ERROR)' | Select-Object -Last 1
    if ($m) { $res = $m.Matches[0].Groups[1].Value }
  }
  $results[$name] = $res
}
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
  while ($queue.Count -gt 0 -and $running.Count -lt $Jobs) {
    $c = $queue.Dequeue()
    $p = Start-Process sby -ArgumentList @('-f', "$($c.Name).sby") -WorkingDirectory $work `
         -RedirectStandardOutput (Join-Path $work "$($c.Name).log") -RedirectStandardError (Join-Path $work "$($c.Name).err") `
         -PassThru -NoNewWindow
    $running[$c.Name] = $p
  }
  Start-Sleep -Milliseconds 300
  foreach ($k in @($running.Keys)) {
    if ($running[$k].HasExited) { Collect $k $running[$k]; $running.Remove($k) }
  }
}

# ---------------------------------------------------------------- report
$bad = 0
"{0,-30} {1,-9} {2,-9} {3}" -f 'case', 'expected', 'actual', 'status'
foreach ($c in $cases) {
  $act = $results[$c.Name]
  $ok = ($act -eq $c.Expect)
  if (-not $ok) { $bad++ }
  "{0,-30} {1,-9} {2,-9} {3}" -f $c.Name, $c.Expect, $act, $(if ($ok) { 'ok' } else { '<== MISMATCH' })
}
''
"{0} cases, {1} mismatches" -f $cases.Count, $bad
if ($bad -ne 0) { exit 1 } else { exit 0 }
