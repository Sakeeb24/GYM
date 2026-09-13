# Shortcut script to invoke tools/ralph/ralph_loop.ps1
param(
    [Parameter(Position=0)]
    [string]$Action = "status",

    [Parameter()]
    [string]$TaskName = "",

    [Parameter()]
    [int]$MaxIterations = 5,

    [Parameter()]
    [string]$TargetTest = "",

    [Parameter()]
    [string]$Summary = "",

    [Parameter()]
    [string]$Status = "IN_PROGRESS",

    [Parameter()]
    [string]$Reason = ""
)

& (Join-Path $PSScriptRoot "..\tools\ralph\ralph_loop.ps1") `
    -Action $Action `
    -TaskName $TaskName `
    -MaxIterations $MaxIterations `
    -TargetTest $TargetTest `
    -Summary $Summary `
    -Status $Status `
    -Reason $Reason
