<#
.SYNOPSIS
  Simulation regression (iverilog): directed + random fix regression, then saturation tests of every arbiter.

.PARAMETER RtlDir  Directory that contains the Arb*.v files (default: the repository root).
.PARAMETER Cycles  Length of every saturation run.
.PARAMETER SkipReqNum1  Skip the REQ_NUM=1 smoke test (REQ_NUM=1 does not compile on the pre-fix RTL).
.PARAMETER OssCad  OSS CAD Suite directory, used when iverilog is not already on PATH.

.EXAMPLE
  .\run_sim.ps1
#>
param(
  [string]$RtlDir = (Join-Path $PSScriptRoot '..\..'),
  [int]$Cycles = 20000,
  [switch]$SkipReqNum1,
  [string]$OssCad = 'C:\Tools\oss-cad-suite'
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command iverilog -ErrorAction SilentlyContinue)) { . (Join-Path $OssCad 'environment.ps1') *> $null }
if (-not (Get-Command iverilog -ErrorAction SilentlyContinue)) { throw 'iverilog not found. Install the OSS CAD Suite or pass -OssCad.' }

$rtl  = (Resolve-Path $RtlDir).Path
$work = Join-Path $PSScriptRoot 'work'
New-Item -ItemType Directory -Force $work | Out-Null
$mods = 'ArbFixedPriorityAbs', 'ArbFixedPriorityNAbs', 'ArbSimpleRR', 'ArbFixedPriorityLocked', 'ArbDynamicPriority', 'ArbPriorityRR', 'ArbBalanceRR'
$rtlFiles = $mods | ForEach-Object { Join-Path $rtl "$_.v" }

function Invoke-Native($exe, $arguments, $tag) {
  $o = Join-Path $work "$tag.out"; $e = Join-Path $work "$tag.err"
  $p = Start-Process $exe -ArgumentList $arguments -RedirectStandardOutput $o -RedirectStandardError $e -PassThru -NoNewWindow
  if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "$exe timeout ($tag)" }
  return [pscustomobject]@{ Exit = $p.ExitCode; Out = (Get-Content $o); Err = (Get-Content $e) }
}

$fail = 0
# ------------------------------------------------------------ 1. regression of the fixes
$vvp = Join-Path $work 'regress.vvp'
if (Test-Path $vvp) { [System.IO.File]::Delete($vvp) }          # never run a stale binary
$def = if ($SkipReqNum1) { @('-DNO_ONE') } else { @() }
$c = Invoke-Native iverilog (@('-g2012', '-s', 'tb_regress') + $def + @('-o', $vvp, (Join-Path $PSScriptRoot 'tb_regress.sv')) + $rtlFiles) 'regress_compile'
if (-not (Test-Path $vvp)) { $c.Err | Select-Object -First 5; 'tb_regress does not compile'; "SIM REGRESSION: FAIL"; exit 1 }
$r = Invoke-Native vvp @((Join-Path $work 'regress.vvp')) 'regress_run'
$r.Out | Where-Object { $_ -match '^(---|FAIL|TB_RESULT)' }
if (-not ($r.Out | Where-Object { $_ -match '^TB_RESULT PASS' })) { $fail++ }

# ------------------------------------------------------------ 2. saturation / fairness
''
"{0,-24} {1,-7} {2,5} {3,10} {4,9} {5}" -f 'module', 'burst/g', 'util', 'multihot', 'revoked', 'grants per master (0..3)'
foreach ($cfg in @(@(4, 1), @(1, 0))) {
  foreach ($m in $mods) {
    if ($m -eq 'ArbFixedPriorityLocked') { continue }      # same as NAbs when lockIn = 0, covered by tb_regress
    $dyn = if ($m -eq 'ArbDynamicPriority') { '-DDYN' } else { '' }
    $iv = @('-g2012', '-s', 'tb_sat', "-DDUTMOD=$m", "-DL=$($cfg[0])", "-DG=$($cfg[1])", "-DCYCLES=$Cycles", '-o', (Join-Path $work "sat_$m.vvp"), (Join-Path $PSScriptRoot 'tb_sat.sv'), (Join-Path $rtl "$m.v"))
    if ($dyn) { $iv = @($dyn) + $iv }
    $sv = Join-Path $work "sat_$m.vvp"
    if (Test-Path $sv) { [System.IO.File]::Delete($sv) }
    $cc = Invoke-Native iverilog $iv "sat_${m}_compile"
    if (-not (Test-Path $sv)) { "$m : saturation testbench does not compile"; $fail++; continue }
    $r = Invoke-Native vvp @((Join-Path $work "sat_$m.vvp")) "sat_${m}_run"
    $res = $r.Out | Where-Object { $_ -match '^RESULT' } | Select-Object -First 1
    $ms  = $r.Out | Where-Object { $_ -match '^\s+m\d:' }
    if (-not $res) { "$m : no result"; $fail++; continue }
    $util = [regex]::Match($res, 'util=(\d+)%').Groups[1].Value
    $mh   = [int][regex]::Match($res, 'multihot=(\d+)').Groups[1].Value
    $grants = @($ms | ForEach-Object { [int][regex]::Match($_, 'grants=(\d+)').Groups[1].Value })
    $revoked = ($ms | ForEach-Object { [int][regex]::Match($_, 'revoked=(\d+)').Groups[1].Value } | Measure-Object -Sum).Sum
    $note = ''
    if ($mh -ne 0) { $fail++; $note = ' <== MULTI-HOT' }
    # fair arbiters must serve everybody and never revoke a grant after the start-up transient
    if ($m -in 'ArbSimpleRR', 'ArbPriorityRR', 'ArbBalanceRR') {
      if (($grants | Where-Object { $_ -eq 0 }).Count -gt 0) { $fail++; $note += ' <== STARVATION' }
      if ($revoked -gt 1) { $fail++; $note += ' <== GRANT REVOKED' }
    }
    "{0,-24} {1,-7} {2,4}% {3,10} {4,9} {5}{6}" -f $m, ("$($cfg[0])/$($cfg[1])"), $util, $mh, $revoked, ($grants -join ' / '), $note
  }
}
''
if ($fail -eq 0) { 'SIM REGRESSION: PASS' } else { "SIM REGRESSION: FAIL ($fail problem(s))" }
exit $(if ($fail -eq 0) { 0 } else { 1 })
