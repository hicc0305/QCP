$ErrorActionPreference = 'Stop'
$output = Join-Path $PSScriptRoot ('results-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $output | Out-Null
Push-Location (Join-Path $PSScriptRoot 'QCP')
try {
    foreach ($case in 'LOS_ListInit', 'List_Add', 'LOS_ListDelete') {
        $prefix = "../$(Split-Path $output -Leaf)/$case"
        & ./win-binary/symexec.exe "--goal-file=${prefix}_goal.v" `
            "--proof-auto-file=${prefix}_proof_auto.v" "--proof-manual-file=${prefix}_proof_manual.v" `
            -slp QCP_examples/ SimpleC.EE -IQCP_examples/ --no-logic-path `
            "--input-file=QCP_examples/LiteOS/$case.c" --no-exec-info > "${prefix}.log"
        $log = Get-Content "${prefix}.log" -Raw
        if ($LASTEXITCODE -ne 0 -or $log -notmatch 'Successfully finished symbolic execution') {
            throw "Symbolic execution failed for $case. See ${prefix}.log."
        }
        foreach ($suffix in 'goal', 'proof_auto', 'goal_check') {
            $generated = (Get-Content "${prefix}_${suffix}.v" -Raw) -replace '\s', ''
            $reference = (Get-Content "SeparationLogic/examples/LiteOS/${case}_${suffix}.v" -Raw) -replace '\s', ''
            if ($generated -cne $reference) {
                throw "$case $suffix differs from the v1.0 reference."
            }
        }
        $auto = @(Select-String "${prefix}_proof_auto.v" -Pattern '^Lemma proof_of_').Count
        $manual = @(Select-String "${prefix}_proof_manual.v" -Pattern '^Lemma proof_of_').Count
        Write-Host "$case  auto=$auto  manual=$manual  generated files match v1.0"
    }
} finally {
    Pop-Location
}
Write-Host "Output: $output"
