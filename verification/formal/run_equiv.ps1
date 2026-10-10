<#
.SYNOPSIS
  Formal equivalence of the current RTL against an older git revision (default: the pre-fix commit 1caa847).

.DESCRIPTION
  The old RTL is taken from `git show <Rev>:<file>` and its top module is renamed <name>_old.
  A miter (fv_equiv_*.sv) proves that both designs produce the same grant on every input sequence,
  except for the behaviors that were deliberately fixed (those traces are excluded by an assumption):
    ArbPriorityRR            : traces where the old design never revokes a grant while req is high
    ArbFixedPriorityLocked   : traces where the old design never grants two sources at once
    ArbDynamicPriority (N=3) : legal priority levels only
  Unchanged files (Abs, NAbs) are skipped.

.PARAMETER Rev     Git revision that holds the old RTL.
.PARAMETER RtlDir  Directory of the current Arb*.v files (default: the repository root).
#>
param(
  [string]$Rev = '1caa847',
  [string]$RtlDir = (Join-Path $PSScriptRoot '..\..'),
  [int]$Jobs = 4,
  [string]$OssCad = 'C:\Tools\oss-cad-suite'
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command sby -ErrorAction SilentlyContinue)) { . (Join-Path $OssCad 'environment.ps1') *> $null }
$repo = (Resolve-Path $RtlDir).Path
$rtl  = $repo -replace '\\', '/'
$here = $PSScriptRoot -replace '\\', '/'
$work = Join-Path $PSScriptRoot 'work_equiv'
New-Item -ItemType Directory -Force $work | Out-Null

$mods = 'ArbSimpleRR', 'ArbFixedPriorityLocked', 'ArbDynamicPriority', 'ArbPriorityRR', 'ArbBalanceRR'
foreach ($m in $mods) {
  $txt = git -C $repo show "${Rev}:$m.v"
  if ($LASTEXITCODE -ne 0 -or -not $txt) { throw "cannot read $m.v from revision $Rev" }
  $txt = ($txt -join "`n") -replace "(?m)^(\s*)module\s+$m\b", "`$1module ${m}_old"
  Set-Content -Path (Join-Path $work "${m}_old.v") -Value $txt -Encoding ASCII
}

$cases = @()
function Add-Eq($name, $mod, $harness, $defs, $chparam) {
  $script:cases += [pscustomobject]@{ Name = $name; Mod = $mod; Harness = $harness; Defs = $defs; Chparam = $chparam }
}
foreach ($n in 4, 3, 5) { Add-Eq "srr_n$n" ArbSimpleRR fv_equiv_std "-DNEWMOD=ArbSimpleRR -DOLDMOD=ArbSimpleRR_old -DN=$n" '' }
foreach ($n in 4, 3, 5, 6) { Add-Eq "bal_n$n" ArbBalanceRR fv_equiv_std "-DNEWMOD=ArbBalanceRR -DOLDMOD=ArbBalanceRR_old -DN=$n" '' }
foreach ($n in 4, 3, 5) { Add-Eq "prr_n$n" ArbPriorityRR fv_equiv_std "-DNEWMOD=ArbPriorityRR -DOLDMOD=ArbPriorityRR_old -DN=$n -DASSUME_NO_REVOKE" '' }
foreach ($n in 4, 3) { Add-Eq "locked_n$n" ArbFixedPriorityLocked fv_equiv_lock "-DNEWMOD=ArbFixedPriorityLocked -DOLDMOD=ArbFixedPriorityLocked_old -DN=$n" '' }
Add-Eq 'dyn_n4' ArbDynamicPriority fv_equiv_dyn '-DNEWMOD=ArbDynamicPriority -DOLDMOD=ArbDynamicPriority_old -DN=4 -DW=2 -DASSUME_LEGAL' ''
Add-Eq 'dyn_n3_legal' ArbDynamicPriority fv_equiv_dyn '-DNEWMOD=ArbDynamicPriority -DOLDMOD=ArbDynamicPriority_old -DN=3 -DW=2 -DASSUME_LEGAL' ''

foreach ($c in $cases) {
  $txt = @"
[tasks]
t

[options]
mode prove
depth 60

[engines]
abc pdr

[script]
read_verilog -formal -sv -I. $($c.Defs) $($c.Mod)_old.v $($c.Mod).v $($c.Harness).sv
prep -top $($c.Harness)

[files]
$(($work -replace '\\', '/'))/$($c.Mod)_old.v
$rtl/$($c.Mod).v
$here/$($c.Harness).sv
"@
  Set-Content -Path (Join-Path $work "$($c.Name).sby") -Value $txt -Encoding ASCII
}

$running = @{}; $queue = New-Object System.Collections.Queue; $results = @{}
foreach ($c in $cases) { $queue.Enqueue($c) }
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
  while ($queue.Count -gt 0 -and $running.Count -lt $Jobs) {
    $c = $queue.Dequeue()
    $running[$c.Name] = Start-Process sby -ArgumentList @('-f', "$($c.Name).sby") -WorkingDirectory $work `
      -RedirectStandardOutput (Join-Path $work "$($c.Name).log") -RedirectStandardError (Join-Path $work "$($c.Name).err") -PassThru -NoNewWindow
  }
  Start-Sleep -Milliseconds 300
  foreach ($k in @($running.Keys)) {
    if ($running[$k].HasExited) {
      $m = Select-String -Path (Join-Path $work "$k.log") -Pattern 'DONE \((PASS|FAIL|UNKNOWN|ERROR)' | Select-Object -Last 1
      $results[$k] = $(if ($m) { $m.Matches[0].Groups[1].Value } else { 'ERROR' })
      $running.Remove($k)
    }
  }
}
$bad = 0
"equivalence of the current RTL and revision $Rev (unchanged: ArbFixedPriorityAbs, ArbFixedPriorityNAbs)"
"{0,-16} {1}" -f 'case', 'result'
foreach ($c in $cases) {
  $r = $results[$c.Name]; if ($r -ne 'PASS') { $bad++ }
  "{0,-16} {1}{2}" -f $c.Name, $r, $(if ($r -ne 'PASS') { '   <== NOT EQUIVALENT' } else { '' })
}
"{0} cases, {1} not equivalent" -f $cases.Count, $bad
exit $(if ($bad -eq 0) { 0 } else { 1 })
