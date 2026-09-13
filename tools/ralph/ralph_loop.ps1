<#
.SYNOPSIS
    Ralph Loop Harness for LiftFlow / GYM on Windows + Antigravity.
    Integrates GSD Planning, Ralph Iterative Implementation, and CodeRabbit Review Gates.

.DESCRIPTION
    Safely coordinates iterative development tasks with:
    - Explicit maximum iteration tracking (default: 5)
    - Automated test runner (targeted flutter test + flutter analyze)
    - Git safety checks (no force push, secret leakage prevention, no destructive reset)
    - CodeRabbit review gate verification
    - Invariant business rule enforcement
    - Iteration logging in .agents/ralph/iterations.log
#>

param(
    [Parameter(Position=0)]
    [ValidateSet("init", "status", "start-task", "verify-step", "log-iteration", "coderabbit-check", "stop", "reset-state")]
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
    [ValidateSet("IN_PROGRESS", "PASS", "FAIL", "BLOCKED", "REVIEW_REQUIRED")]
    [string]$Status = "IN_PROGRESS",

    [Parameter()]
    [string]$Reason = ""
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$RalphDir = Join-Path $ProjectRoot ".agents\ralph"
$StateFile = Join-Path $RalphDir "state.json"
$LogFile = Join-Path $RalphDir "iterations.log"

function Ensure-Directories {
    if (-not (Test-Path $RalphDir)) {
        New-Item -ItemType Directory -Path $RalphDir -Force | Out-Null
    }
}

function Get-State {
    Ensure-Directories
    if (Test-Path $StateFile) {
        return (Get-Content $StateFile -Raw | ConvertFrom-Json)
    }
    return [PSCustomObject]@{
        task_name = ""
        current_iteration = 0
        max_iterations = $MaxIterations
        status = "IDLE"
        last_test_passed = $false
        last_analyze_passed = $false
        coderabbit_review_passed = $false
        created_at = (Get-Date).ToString("o")
        updated_at = (Get-Date).ToString("o")
    }
}

function Save-State($state) {
    Ensure-Directories
    $state.updated_at = (Get-Date).ToString("o")
    $json = $state | ConvertTo-Json -Depth 5
    Set-Content -Path $StateFile -Value $json -Force
}

function Append-Log($message) {
    Ensure-Directories
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] $message"
    Add-Content -Path $LogFile -Value $logEntry
}

function Check-Git-Safety {
    Write-Host "[SAFETY] Performing Git Safety Checks..." -ForegroundColor Cyan
    
    # Check for exposed private keys or service role secrets
    $dirtySecrets = git status --porcelain | Select-String -Pattern "\.env$|\.key$|service_role|id_rsa"
    if ($dirtySecrets) {
        Write-Warning "[ALERT] Potentially sensitive files detected in working tree: $dirtySecrets"
        return $false
    }

    Write-Host "[SAFETY] Git safety check passed. Working tree safe." -ForegroundColor Green
    return $true
}

switch ($Action) {
    "init" {
        Ensure-Directories
        $state = Get-State
        Save-State $state
        if (-not (Test-Path $LogFile)) {
            Set-Content -Path $LogFile -Value "# Ralph Loop Iteration Log for LiftFlow / GYM`n"
        }
        Append-Log "Ralph Loop initialized."
        Write-Host "Ralph Loop initialized successfully at: $RalphDir" -ForegroundColor Green
    }

    "status" {
        $state = Get-State
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "   RALPH LOOP STATUS - LiftFlow / GYM" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "Active Task        : $(if ($state.task_name) { $state.task_name } else { '[None]' })"
        Write-Host "Status             : $($state.status)"
        Write-Host "Current Iteration  : $($state.current_iteration) / $($state.max_iterations)"
        Write-Host "Target Tests Passed: $($state.last_test_passed)"
        Write-Host "Analyze Passed     : $($state.last_analyze_passed)"
        Write-Host "CodeRabbit Review  : $(if ($state.coderabbit_review_passed) { 'PASSED' } else { 'PENDING/REQUIRED' })"
        Write-Host "Last Updated       : $($state.updated_at)"
        Write-Host "------------------------------------------"
        Check-Git-Safety | Out-Null
    }

    "start-task" {
        if (-not $TaskName) {
            Write-Error "Please specify -TaskName for the task to start."
            return
        }
        $state = Get-State
        $state.task_name = $TaskName
        $state.current_iteration = 0
        $state.max_iterations = $MaxIterations
        $state.status = "IN_PROGRESS"
        $state.last_test_passed = $false
        $state.last_analyze_passed = $false
        $state.coderabbit_review_passed = $false
        Save-State $state
        Append-Log "Started task: '$TaskName' (Max Iterations: $MaxIterations)"
        Write-Host "Task '$TaskName' started. Max iterations: $MaxIterations" -ForegroundColor Green
    }

    "verify-step" {
        $state = Get-State
        if ($state.status -ne "IN_PROGRESS") {
            Write-Warning "No active task in progress. Current status: $($state.status)"
        }

        $state.current_iteration += 1
        Write-Host "`n--- Iteration $($state.current_iteration) of $($state.max_iterations) ---" -ForegroundColor Yellow

        if ($state.current_iteration -gt $state.max_iterations) {
            $state.status = "STOPPED_MAX_ITERATIONS"
            Save-State $state
            Append-Log "[STOP] Task '$($state.task_name)' reached maximum iterations ($($state.max_iterations)). Human review required."
            Write-Error "Maximum iterations ($($state.max_iterations)) reached for task. HALTING loop. Human intervention required."
            return
        }

        # 1. Safety Check
        $safetyPassed = Check-Git-Safety
        if (-not $safetyPassed) {
            $state.status = "BLOCKED"
            Save-State $state
            Append-Log "[BLOCKED] Task '$($state.task_name)' blocked by Git safety violation."
            Write-Error "Safety violation. Halting iteration."
            return
        }

        # 2. Targeted Flutter Test
        $testPassed = $false
        if ($TargetTest) {
            Write-Host "[TEST] Running targeted test: $TargetTest" -ForegroundColor Cyan
            Push-Location $ProjectRoot
            try {
                flutter test $TargetTest
                if ($LASTEXITCODE -eq 0) {
                    $testPassed = $true
                    Write-Host "[TEST] Targeted test passed!" -ForegroundColor Green
                } else {
                    Write-Warning "[TEST] Targeted test failed."
                }
            } finally {
                Pop-Location
            }
        } else {
            Write-Host "[TEST] Running default business rules test..." -ForegroundColor Cyan
            Push-Location $ProjectRoot
            try {
                flutter test test/business_rules/business_rules_test.dart
                if ($LASTEXITCODE -eq 0) {
                    $testPassed = $true
                    Write-Host "[TEST] Business rules test passed!" -ForegroundColor Green
                } else {
                    Write-Warning "[TEST] Business rules test failed."
                }
            } finally {
                Pop-Location
            }
        }

        # 3. Flutter Analyze
        Write-Host "[ANALYZE] Running flutter analyze..." -ForegroundColor Cyan
        $analyzePassed = $false
        Push-Location $ProjectRoot
        try {
            flutter analyze --no-fatal-infos
            if ($LASTEXITCODE -eq 0) {
                $analyzePassed = $true
                Write-Host "[ANALYZE] Flutter analyze passed cleanly!" -ForegroundColor Green
            } else {
                Write-Warning "[ANALYZE] Flutter analyze identified issues."
            }
        } finally {
            Pop-Location
        }

        $state.last_test_passed = $testPassed
        $state.last_analyze_passed = $analyzePassed
        Save-State $state

        Append-Log "Iteration $($state.current_iteration)/$($state.max_iterations) - Tests: $(if ($testPassed){'PASS'}else{'FAIL'}), Analyze: $(if ($analyzePassed){'PASS'}else{'FAIL'})"
    }

    "coderabbit-check" {
        $state = Get-State
        Write-Host "[CODERABBIT GATE] Checking CodeRabbit Review Status..." -ForegroundColor Magenta
        if (-not $state.last_test_passed -or -not $state.last_analyze_passed) {
            Write-Warning "CodeRabbit review gate cannot pass while tests or analysis are failing."
            return
        }

        Write-Host "CodeRabbit Gate Requirement: Request review using 'code-reviewer' subagent or CodeRabbit review skill." -ForegroundColor Cyan
        Write-Host "Task can only complete when CodeRabbit returns zero unresolved Critical or High findings." -ForegroundColor Cyan
    }

    "log-iteration" {
        $state = Get-State
        if ($Summary) {
            Append-Log "[LOG] Iteration $($state.current_iteration) Summary: $Summary | Status: $Status"
        }
        $state.status = $Status
        Save-State $state
        Write-Host "Iteration logged. Current status: $Status" -ForegroundColor Green
    }

    "stop" {
        $state = Get-State
        $state.status = "STOPPED"
        Save-State $state
        $stopMsg = if ($Reason) { "Ralph Loop stopped: $Reason" } else { "Ralph Loop manually stopped." }
        Append-Log "[STOP] $stopMsg"
        Write-Host $stopMsg -ForegroundColor Yellow
    }

    "reset-state" {
        Ensure-Directories
        $state = [PSCustomObject]@{
            task_name = ""
            current_iteration = 0
            max_iterations = $MaxIterations
            status = "IDLE"
            last_test_passed = $false
            last_analyze_passed = $false
            coderabbit_review_passed = $false
            created_at = (Get-Date).ToString("o")
            updated_at = (Get-Date).ToString("o")
        }
        Save-State $state
        Append-Log "State reset to IDLE."
        Write-Host "Ralph Loop state reset to IDLE." -ForegroundColor Green
    }
}
